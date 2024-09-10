// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contract
import { Errors } from "../../../../../contracts/lib/Errors.sol";

// test
import { BaseIntegration } from "../../BaseIntegration.t.sol";

contract Flows_Integration_Disputes is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;
    uint256 internal ncSocialRemixTermsId;

    function setUp() public override {
        super.setUp();

        ncSocialRemixTermsId = registerSelectedPILicenseTerms_NonCommercialSocialRemixing();

        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);
        mockNFT.mintId(u.carl, 3);

        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        ipAcct[2] = registerIpAccount(mockNFT, 2, u.bob);
        ipAcct[3] = registerIpAccount(mockNFT, 3, u.carl);

        vm.startPrank(u.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                ncSocialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), ncSocialRemixTermsId);
        vm.stopPrank();
    }

    function test_Integration_Disputes_revert_cannotMintFromDisputedIp() public {
        assertEq(licenseToken.balanceOf(u.carl), 0);

        vm.prank(u.carl);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: ncSocialRemixTermsId,
            amount: 1,
            receiver: u.carl,
            royaltyContext: ""
        });
        assertEq(licenseToken.balanceOf(u.carl), 1);

        _disputeIp(u.bob, ipAcct[1]);

        vm.prank(u.carl);
        vm.expectRevert(Errors.LicensingModule__DisputedIpId.selector);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: ncSocialRemixTermsId,
            amount: 1,
            receiver: u.carl,
            royaltyContext: ""
        });
    }

    function test_Integration_Disputes_revert_cannotRegisterDerivativeWithTokensFromDisputedIpParent() public {
        assertEq(licenseToken.balanceOf(u.carl), 0);

        vm.prank(u.carl);
        uint256 licenseId = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: ncSocialRemixTermsId,
            amount: 1,
            receiver: u.carl,
            royaltyContext: ""
        });
        assertEq(licenseToken.balanceOf(u.carl), 1);

        _disputeIp(u.bob, ipAcct[1]);

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseToken__RevokedLicense.selector, licenseId));
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[3], licenseIds, "");
    }

    function test_Integration_Disputes_revert_cannotRegisterDerivativeFromDisputedIpParent() public {
        _disputeIp(u.bob, ipAcct[1]);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = ncSocialRemixTermsId;

        vm.prank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__ParentIpTagged.selector, ipAcct[1]));
        licensingModule.registerDerivative({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: ""
        });
    }

    function test_Integration_Disputes_transferLicenseAfterIpDispute() public {
        assertEq(licenseToken.balanceOf(u.carl), 0);

        vm.prank(u.carl);
        uint256 licenseId = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: ncSocialRemixTermsId,
            amount: 1,
            receiver: u.carl,
            royaltyContext: ""
        });
        assertEq(licenseToken.balanceOf(u.carl), 1);

        _disputeIp(u.bob, ipAcct[1]);

        // If the IP asset is disputed, license owners won't be able to transfer license NFTs
        vm.prank(u.carl);
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseToken__RevokedLicense.selector, licenseId));
        licenseToken.transferFrom(u.carl, u.bob, licenseId);
    }

    function test_Integration_Disputes_mintLicenseAfterDisputeIsResolved() public {
        uint256 disputeId = _disputeIp(u.bob, ipAcct[1]);

        vm.prank(u.bob);
        disputeModule.resolveDispute(disputeId, "");

        assertEq(licenseToken.balanceOf(u.carl), 0);

        vm.prank(u.carl);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: ncSocialRemixTermsId,
            amount: 1,
            receiver: u.carl,
            royaltyContext: ""
        });
        assertEq(licenseToken.balanceOf(u.carl), 1);
    }
}
