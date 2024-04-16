// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// contract
import { Errors } from "../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../contracts/lib/PILFlavors.sol";
import { PILTerms } from "../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { LicenseToken } from "../../contracts/LicenseToken.sol";

// test
import { BaseTest } from "./utils/BaseTest.t.sol";

contract LicenseTokenTest is BaseTest {
    mapping(uint256 => address) internal ipAcct;
    mapping(uint256 => address) internal ipOwner;
    mapping(uint256 => uint256) internal tokenIds;

    uint256 internal commTermsId;

    function setUp() public override {
        super.setUp();

        ipOwner[1] = u.alice;
        ipOwner[2] = u.bob;

        tokenIds[1] = mockNFT.mint(ipOwner[1]);
        tokenIds[2] = mockNFT.mint(ipOwner[2]);

        ipAcct[1] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[1]);
        vm.label(ipAcct[1], "IPAccount1");

        commTermsId = registerSelectedPILicenseTerms(
            "commercial_use",
            PILFlavors.commercialUse({
                mintingFee: 1 ether,
                currencyToken: address(USDC),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
    }

    modifier whenCallerIsProtocolManager() {
        vm.startPrank(u.admin);
        _;
    }

    function test_LicenseToken_setDisputeModule() public whenCallerIsProtocolManager {
        licenseToken.setDisputeModule(address(1));
        assertEq(address(licenseToken.disputeModule()), address(1));
    }

    function test_LicenseToken_revert_setDisputeModule_zeroDisputeModule() public whenCallerIsProtocolManager {
        vm.expectRevert(Errors.LicenseToken__ZeroDisputeModule.selector);
        licenseToken.setDisputeModule(address(0));
    }

    function test_LicenseToken_setLicensingModule() public whenCallerIsProtocolManager {
        licenseToken.setLicensingModule(address(1));
        assertEq(address(licenseToken.licensingModule()), address(1));
    }

    function test_LicenseToken_revert_setLicensingModule_zeroLicensingModule() public whenCallerIsProtocolManager {
        vm.expectRevert(Errors.LicenseToken__ZeroLicensingModule.selector);
        licenseToken.setLicensingModule(address(0));
    }

    function test_LicenseToken_setLicensingImageUrl() public whenCallerIsProtocolManager {
        vm.expectEmit(address(licenseToken));
        emit LicenseToken.BatchMetadataUpdate(1, 0);
        licenseToken.setLicensingImageUrl("new_url");
    }

    function test_LicenseToken_isLicenseTokenRevoked() public {
        uint256 mintAmount = 10;

        vm.prank(address(licensingModule));
        uint256 startLicenseTokenId = licenseToken.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commTermsId,
            amount: mintAmount,
            minter: ipOwner[1],
            receiver: ipOwner[1]
        });

        for (uint256 i = 0; i < mintAmount; i++) {
            assertFalse(licenseToken.isLicenseTokenRevoked(startLicenseTokenId + i));
        }

        _disputeIp(u.bob, ipAcct[1]);

        // After ipAcct[1] is disputed, expect all license tokens with licensor = ipAcct[1] to be revoked
        for (uint256 i = 0; i < mintAmount; i++) {
            assertTrue(licenseToken.isLicenseTokenRevoked(startLicenseTokenId + i));
        }
    }

    function test_LicenseToken_revert_transfer_revokedLicense() public {
        vm.prank(address(licensingModule));
        uint256 licenseTokenId = licenseToken.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commTermsId,
            amount: 1,
            minter: ipOwner[1],
            receiver: ipOwner[1]
        });

        vm.prank(ipOwner[1]);
        licenseToken.transferFrom(ipOwner[1], ipOwner[2], licenseTokenId);
        assertEq(licenseToken.balanceOf(ipOwner[1]), 0);
        assertEq(licenseToken.balanceOf(ipOwner[2]), 1);

        // make all license tokens with "licensor = ipAcct[1]" revoked
        _disputeIp(u.bob, ipAcct[1]);

        vm.prank(ipOwner[2]);
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseToken__RevokedLicense.selector, licenseTokenId));
        licenseToken.transferFrom(ipOwner[2], ipOwner[1], licenseTokenId);
        assertEq(licenseToken.balanceOf(ipOwner[1]), 0);
        assertEq(licenseToken.balanceOf(ipOwner[2]), 1);
    }

    function test_LicenseToken_revert_transfer_notTransferable() public {
        uint256 licenseTermsId = pilTemplate.registerLicenseTerms(
            PILTerms({
                transferable: false,
                royaltyPolicy: address(0),
                mintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                commercialRevCelling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCelling: 0,
                currency: address(USDC),
                uri: ""
            })
        );

        vm.prank(address(licensingModule));
        uint256 licenseTokenId = licenseToken.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsId,
            amount: 1,
            minter: ipOwner[1],
            receiver: ipOwner[1]
        });

        vm.expectRevert(Errors.LicenseToken__NotTransferable.selector);
        vm.prank(ipOwner[1]);
        licenseToken.transferFrom(ipOwner[1], ipOwner[2], licenseTokenId);
        assertEq(licenseToken.balanceOf(ipOwner[1]), 1);
        assertEq(licenseToken.balanceOf(ipOwner[2]), 0);
    }
}
