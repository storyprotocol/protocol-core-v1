// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract
import { Errors } from "contracts/lib/Errors.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";

contract Flows_Integration_Disputes is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;
    uint256 internal policyId;

    function setUp() public override {
        super.setUp();

        // Register PIL Framework
        _setPILPolicyFrameworkManager();

        // Register a License
        _mapPILPolicySimple({
            name: "non-commercial-remix",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 0
        });
        policyId = _registerPILPolicyFromMapping("non-commercial-remix");

        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);
        mockNFT.mintId(u.carl, 3);

        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        ipAcct[2] = registerIpAccount(mockNFT, 2, u.bob);
        ipAcct[3] = registerIpAccount(mockNFT, 3, u.carl);

        vm.startPrank(u.alice);
        licensingModule.addPolicyToIp(ipAcct[1], _getPilPolicyId("non-commercial-remix"));
        vm.stopPrank();
    }

    function test_Integration_Disputes_revert_cannotMintFromDisputedIp() public {
        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 0);
        vm.prank(u.carl);
        licensingModule.mintLicense(policyId, ipAcct[1], 1, u.carl, "");
        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 1);

        _disputeIp(u.bob, ipAcct[1]);

        vm.prank(u.carl);
        vm.expectRevert(Errors.LicensingModule__DisputedIpId.selector);
        licensingModule.mintLicense(policyId, ipAcct[1], 1, u.carl, "");
    }

    function test_Integration_Disputes_revert_cannotLinkDisputedIp() public {
        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 0);
        vm.prank(u.carl);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipAcct[1], 1, u.carl, "");
        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 1);

        _disputeIp(u.bob, ipAcct[1]);

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(u.carl);
        vm.expectRevert(Errors.LicensingModule__LinkingRevokedLicense.selector);
        licensingModule.linkIpToParents(licenseIds, ipAcct[3], "");
    }

    function test_Integration_Disputes_transferLicenseAfterIpDispute() public {
        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 0);
        vm.prank(u.carl);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipAcct[1], 1, u.carl, "");
        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 1);

        _disputeIp(u.bob, ipAcct[1]);

        // If the IP asset is disputed, license owners won't be able to transfer license NFTs
        vm.prank(u.carl);
        vm.expectRevert(Errors.LicenseRegistry__RevokedLicense.selector);
        licenseRegistry.safeTransferFrom(u.carl, u.bob, licenseId, 1, "");
    }

    function test_Integration_Disputes_mintLicenseAfterDisputeIsResolved() public {
        uint256 disputeId = _disputeIp(u.bob, ipAcct[1]);

        vm.prank(u.bob);
        disputeModule.resolveDispute(disputeId);

        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 0);
        vm.prank(u.carl);
        licensingModule.mintLicense(policyId, ipAcct[1], 1, u.carl, "");
        assertEq(licenseRegistry.balanceOf(u.carl, policyId), 1);
    }

    function _disputeIp(address disputeInitiator, address ipAddrToDispute) internal returns (uint256 disputeId) {
        vm.startPrank(disputeInitiator);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeId = disputeModule.raiseDispute(ipAddrToDispute, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.prank(u.admin); // admin is a judge
        disputeModule.setDisputeJudgement(disputeId, true, "");
    }
}
