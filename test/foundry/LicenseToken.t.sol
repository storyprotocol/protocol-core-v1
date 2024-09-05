// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
// contract
import { Errors } from "../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../contracts/lib/PILFlavors.sol";
import { PILTerms } from "../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { LicenseToken } from "../../contracts/LicenseToken.sol";
import { ILicenseToken } from "../../contracts/interfaces/ILicenseToken.sol";

// test
import { BaseTest } from "./utils/BaseTest.t.sol";

contract LicenseTokenTest is BaseTest {
    using Strings for *;

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
                defaultMintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
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

    function test_LicenseToken_TokenURI() public {
        uint256 licenseTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());

        vm.prank(address(licensingModule));
        uint256 licenseTokenId = licenseToken.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsId,
            amount: 1,
            minter: ipOwner[1],
            receiver: ipOwner[1]
        });

        string memory tokenURI = licenseToken.tokenURI(licenseTokenId);
        /* solhint-disable */
        bytes memory expectedURI = abi.encodePacked(
            '{"name": "Story Protocol License #0","description": "License agreement stating the terms of a Story Protocol IPAsset","external_url": "https://protocol.storyprotocol.xyz/ipa/',
            ipAcct[1].toHexString(),
            '","image": "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"'
        );
        expectedURI = abi.encodePacked(
            expectedURI,
            ',"attributes": [{"trait_type": "Expiration", "value": "never"},{"trait_type": "Currency", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "URI", "value": ""},{"trait_type": "Commercial Use", "value": "false"},{"trait_type": "Commercial Attribution", "value": "false"},{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": 0},{"trait_type": "Commercial Revenue Ceiling", "value": 0},{"trait_type": "Commercializer Check", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "Derivatives Allowed", "value": "true"},{"trait_type": "Derivatives Attribution", "value": "true"},{"trait_type": "Derivatives Revenue Ceiling", "value": 0},{"trait_type": "Derivatives Approval", "value": "false"},{"trait_type": "Derivatives Reciprocal", "value": "true"}'
        );
        expectedURI = abi.encodePacked(
            expectedURI,
            ',{"trait_type": "Licensor", "value": "',
            ipAcct[1].toHexString(),
            '"},{"trait_type": "License Template", "value": "',
            address(pilTemplate).toHexString(),
            '"},{"trait_type": "License Terms ID", "value": "',
            licenseTermsId.toString(),
            '"},{"trait_type": "Transferable", "value": "true"},{"trait_type": "Revoked", "value": "false"}]}'
        );
        /* solhint-enable */
        expectedURI = abi.encodePacked("data:application/json;base64,", Base64.encode(expectedURI));
        assertEq(tokenURI, string(expectedURI));
    }

    function test_LicenseToken_getLicenseTokenMetadata() public {
        uint256 licenseTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());

        vm.prank(address(licensingModule));
        uint256 licenseTokenId = licenseToken.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: licenseTermsId,
            amount: 1,
            minter: ipOwner[1],
            receiver: ipOwner[1]
        });

        ILicenseToken.LicenseTokenMetadata memory lmt = licenseToken.getLicenseTokenMetadata(licenseTokenId);
        assertEq(lmt.licensorIpId, ipAcct[1]);
        assertEq(lmt.licenseTemplate, address(pilTemplate));
        assertEq(lmt.licenseTermsId, licenseTermsId);
        assertEq(lmt.transferable, true);
    }
}
