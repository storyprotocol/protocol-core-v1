// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// contracts
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
import { ILicensingModule } from "../../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { MockTokenGatedHook } from "../../mocks/MockTokenGatedHook.sol";
import { MockLicenseTemplate } from "../../mocks/module/MockLicenseTemplate.sol";
import { MockLicensingHook } from "../../mocks/module/MockLicensingHook.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { Licensing } from "../../../../contracts/lib/Licensing.sol";
import { AccessPermission } from "../../../../contracts/lib/AccessPermission.sol";

// test
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract LicensingModuleTest is BaseTest {
    using Strings for *;

    error ERC721NonexistentToken(uint256 tokenId);

    MockERC721 internal mockNft = new MockERC721("MockERC721");
    MockERC721 internal gatedNftFoo = new MockERC721{ salt: bytes32(uint256(1)) }("GatedNftFoo");
    MockERC721 internal gatedNftBar = new MockERC721{ salt: bytes32(uint256(2)) }("GatedNftBar");

    address public ipId1;
    address public ipId2;
    address public ipId3;
    address public ipId5;
    address public ipOwner1 = address(0x111);
    address public ipOwner2 = address(0x222);
    address public ipOwner3 = address(0x333);
    address public ipOwner5 = address(0x444);
    uint256 public tokenId1 = 1;
    uint256 public tokenId2 = 2;
    uint256 public tokenId3 = 3;
    uint256 public tokenId5 = 5;

    address public licenseHolder = address(0x101);

    function setUp() public override {
        super.setUp();
        // Create IPAccounts
        mockNft.mintId(ipOwner1, tokenId1);
        mockNft.mintId(ipOwner2, tokenId2);
        mockNft.mintId(ipOwner3, tokenId3);
        mockNft.mintId(ipOwner5, tokenId5);

        ipId1 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId1);
        ipId2 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId2);
        ipId3 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId3);
        ipId5 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId5);

        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
        vm.label(ipId3, "IPAccount3");
        vm.label(ipId5, "IPAccount5");
    }

    function test_LicensingModule_attachLicenseTerms_attachOneLicenseToOneIP() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.expectEmit();
        emit ILicensingModule.LicenseTermsAttached(ipOwner1, ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 2);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), termsId).isSet);
        assertEq(licenseRegistry.getExpireTime(ipId1), 0);
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));
        assertTrue(licenseRegistry.exists(address(pilTemplate), termsId));
    }

    function test_LicensingModule_attachLicenseTerms_sameLicenseAttachMultipleIP() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());

        vm.expectEmit();
        emit ILicensingModule.LicenseTermsAttached(ipOwner1, ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 2);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), termsId).isSet);
        assertEq(licenseRegistry.getExpireTime(ipId1), 0);
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));
        assertTrue(licenseRegistry.exists(address(pilTemplate), termsId));

        vm.expectEmit();
        emit ILicensingModule.LicenseTermsAttached(ipOwner2, ipId2, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 2);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId2), 0);
        assertFalse(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), termsId).isSet);
        assertEq(licenseRegistry.getExpireTime(ipId2), 0);
        assertFalse(licenseRegistry.isDerivativeIp(ipId2));
        assertTrue(licenseRegistry.exists(address(pilTemplate), termsId));
    }

    function test_LicensingModule_attachLicenseTerms_DifferentLicensesAttachToSameIP() public {
        uint256 termsId1 = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.expectEmit();
        emit ILicensingModule.LicenseTermsAttached(ipOwner1, ipId1, address(pilTemplate), termsId1);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId1);
        (address licenseTemplate1, uint256 licenseTermsId1) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate1, address(pilTemplate));
        assertEq(licenseTermsId1, termsId1);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId1));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 2);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), termsId1).isSet);
        assertEq(licenseRegistry.getExpireTime(ipId1), 0);
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));
        assertTrue(licenseRegistry.exists(address(pilTemplate), termsId1));

        uint256 termsId2 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.expectEmit();
        emit ILicensingModule.LicenseTermsAttached(ipOwner1, ipId1, address(pilTemplate), termsId2);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId2);
        (address licenseTemplate2, uint256 licenseTermsId2) = licenseRegistry.getAttachedLicenseTerms(ipId1, 1);
        assertEq(licenseTemplate2, address(pilTemplate));
        assertEq(licenseTermsId2, termsId2);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId2));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 3);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), termsId2).isSet);
        assertEq(licenseRegistry.getExpireTime(ipId1), 0);
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));
        assertTrue(licenseRegistry.exists(address(pilTemplate), termsId2));
    }

    function test_LicensingModule_attachLicenseTerms_revert_licenseNotExist() public {
        uint256 nonExistTermsId = 9999;
        assertFalse(licenseRegistry.exists(address(pilTemplate), nonExistTermsId));

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseTermsNotFound.selector,
                address(pilTemplate),
                nonExistTermsId
            )
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), nonExistTermsId);
    }

    function test_LicensingModule_attachLicenseTerms_revert_IpExpired() public {
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);
        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(royaltyPolicyLAP),
            defaultMintingFee: 0,
            expiration: 10 days,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: address(0x123),
            uri: ""
        });

        uint256 termsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });
        assertEq(licenseToken.ownerOf(lcTokenId), ipOwner2);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId2), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId2);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);
        assertEq(licenseRegistry.getParentIpCount(ipId2), 1);
        assertEq(licenseToken.totalSupply(), 0);
        assertEq(licenseToken.totalMintedTokens(), 1);
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        licenseToken.ownerOf(lcTokenId);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);

        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: address(ipOwner2),
            royaltyContext: ""
        });

        vm.warp(11 days);
        uint256 anotherTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IpExpired.selector, ipId2));
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), anotherTermsId);
    }

    function test_LicensingModule_attachLicenseTerms_revert_attachSameLicenseToIpTwice() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
    }

    function test_LicensingModule_attachLicenseTerms_revert_attachLicenseDifferentTemplate() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        MockLicenseTemplate mockLicenseTemplate = new MockLicenseTemplate();
        vm.prank(admin);
        licenseRegistry.registerLicenseTemplate(address(mockLicenseTemplate));
        uint256 mockTermsId = mockLicenseTemplate.registerLicenseTerms();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__UnmatchedLicenseTemplate.selector,
                ipId1,
                address(pilTemplate),
                address(mockLicenseTemplate)
            )
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(mockLicenseTemplate), mockTermsId);
    }

    function test_LicensingModule_attachLicenseTerms_revert_Unregistered_LicenseTemplate() public {
        MockLicenseTemplate mockLicenseTemplate = new MockLicenseTemplate();
        uint256 mockTermsId = mockLicenseTemplate.registerLicenseTerms();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseTermsNotFound.selector,
                address(mockLicenseTemplate),
                mockTermsId
            )
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(mockLicenseTemplate), mockTermsId);
    }

    function test_LicensingModule_attachLicenseTerms_revert_NonExists_LicenseTerms() public {
        uint256 nonExistsTermsId = 9999;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseTermsNotFound.selector,
                address(pilTemplate),
                nonExistsTermsId
            )
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), nonExistsTermsId);
    }

    function test_LicensingModule_mintLicenseTokens_singleToken() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x111);
        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(address(this), ipId1, address(pilTemplate), termsId, 1, receiver, 0);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: ""
        });
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 0), lcTokenId);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(receiver), 1);
    }

    function test_LicensingModule_mintLicenseTokens_mintMultipleTokens() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x111);
        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(address(this), ipId1, address(pilTemplate), termsId, 2, receiver, 0);
        uint256 firstTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 2,
            receiver: receiver,
            royaltyContext: ""
        });
        assertEq(licenseToken.ownerOf(firstTokenId), receiver);
        assertEq(licenseToken.getLicenseTermsId(firstTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(firstTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(firstTokenId), ipId1);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 0), firstTokenId);

        uint256 secondTokenId = firstTokenId + 1;

        assertEq(licenseToken.ownerOf(secondTokenId), receiver);
        assertEq(licenseToken.getLicenseTermsId(secondTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(secondTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(secondTokenId), ipId1);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 1), secondTokenId);
        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(licenseToken.totalSupply(), 2);
        assertEq(licenseToken.balanceOf(receiver), 2);
    }

    function test_LicensingModule_mintLicenseTokens_mintMultipleTimes() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x111);
        for (uint i = 0; i < 10; i++) {
            vm.expectEmit();
            emit ILicensingModule.LicenseTokensMinted(
                address(this),
                ipId1,
                address(pilTemplate),
                termsId,
                1,
                receiver,
                i
            );
            uint256 tokenId = licensingModule.mintLicenseTokens({
                licensorIpId: ipId1,
                licenseTemplate: address(pilTemplate),
                licenseTermsId: termsId,
                amount: 1,
                receiver: receiver,
                royaltyContext: ""
            });
            assertEq(licenseToken.ownerOf(tokenId), receiver);
            assertEq(licenseToken.getLicenseTermsId(tokenId), termsId);
            assertEq(licenseToken.getLicenseTemplate(tokenId), address(pilTemplate));
            assertEq(licenseToken.getLicensorIpId(tokenId), ipId1);
            assertEq(licenseToken.tokenOfOwnerByIndex(receiver, i), tokenId);
            assertEq(licenseToken.totalMintedTokens(), i + 1);
            assertEq(licenseToken.totalSupply(), i + 1);
            assertEq(licenseToken.balanceOf(receiver), i + 1);
        }
    }

    function test_LicensingModule_mintLicenseTokens_ExpirationTime() public {
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);
        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(royaltyPolicyLAP),
            defaultMintingFee: 0,
            expiration: 10 days,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: address(0x123),
            uri: ""
        });

        uint256 termsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });
        assertEq(licenseToken.ownerOf(lcTokenId), ipOwner2);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);
    }

    function test_LicensingModule_mintLicenseTokens_revert_licensorIpNotRegistered() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.expectRevert(abi.encodeWithSelector(Errors.LicensingModule__LicensorIpNotRegistered.selector));
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: address(0x123),
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: address(0x777),
            royaltyContext: ""
        });
    }

    function test_LicensingModule_mintLicenseTokens_revert_invalidInputs() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x111);
        vm.expectRevert(Errors.LicensingModule__MintAmountZero.selector);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 0,
            receiver: receiver,
            royaltyContext: ""
        });

        vm.expectRevert(Errors.LicensingModule__ReceiverZeroAddress.selector);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: address(0),
            royaltyContext: ""
        });
    }

    function test_LicensingModule_mintLicenseTokens_revert_NonIpOwnerMintNotAttachedLicense() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        address receiver = address(0x111);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicensorIpHasNoLicenseTerms.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: ""
        });
    }

    function test_LicensingModule_mintLicenseTokens_revert_IpOwnerMintNonExistsLicense() public {
        address receiver = address(0x111);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseRegistry__LicenseTermsNotExists.selector, address(pilTemplate), 9999)
        );
        vm.prank(ipOwner1);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: 9999,
            amount: 1,
            receiver: receiver,
            royaltyContext: ""
        });
    }

    function test_LicensingModule_mintLicenseTokens_revert_paused() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.prank(u.admin);
        licensingModule.pause();

        address receiver = address(0x111);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        emit ILicensingModule.LicenseTokensMinted(address(this), ipId1, address(pilTemplate), termsId, 2, receiver, 0);
        uint256 firstTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 2,
            receiver: receiver,
            royaltyContext: ""
        });
    }

    function test_LicensingModule_mintLicenseTokens_IpOwnerMintNotAttachedLicense() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        address receiver = address(0x111);
        vm.prank(ipOwner1);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: ""
        });
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 0), lcTokenId);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(receiver), 1);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_singleParent() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });
        assertEq(licenseToken.ownerOf(lcTokenId), ipOwner2);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId2), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId2);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);
        assertEq(licenseRegistry.getParentIpCount(ipId2), 1);
        assertEq(licenseToken.totalSupply(), 0);
        assertEq(licenseToken.totalMintedTokens(), 1);
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        licenseToken.ownerOf(lcTokenId);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_privateLicense() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId), false);

        assertEq(licenseToken.ownerOf(lcTokenId), ipOwner2);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId), false);

        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId2), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId2);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);
        assertEq(licenseRegistry.getParentIpCount(ipId2), 1);
        assertEq(licenseToken.totalSupply(), 0);
        assertEq(licenseToken.totalMintedTokens(), 1);
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        licenseToken.ownerOf(lcTokenId);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_pause() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });

        vm.prank(u.admin);
        licensingModule.pause();

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_twoParents() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId2,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

        uint256 lcTokenId1 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        assertEq(licenseToken.ownerOf(lcTokenId1), ipOwner3);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId1), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId1), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId1), ipId1);

        assertEq(licenseToken.ownerOf(lcTokenId2), ipOwner3);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId2), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId2), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId2), ipId2);

        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(licenseToken.totalSupply(), 2);
        assertEq(licenseToken.balanceOf(ipOwner3), 2);

        uint256[] memory licenseTokens = new uint256[](2);
        licenseTokens[0] = lcTokenId1;
        licenseTokens[1] = lcTokenId2;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId3), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipId3), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId3), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId3), 0);

        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId3);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 1);

        assertEq(licenseRegistry.hasDerivativeIps(ipId2), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), false);
        assertEq(licenseRegistry.getDerivativeIp(ipId2, 0), ipId3);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 1);

        assertEq(licenseRegistry.getParentIpCount(ipId3), 2);
        assertEq(licenseRegistry.getParentIp(ipId3, 0), ipId1);
        assertEq(licenseRegistry.getParentIp(ipId3, 1), ipId2);

        assertEq(licenseToken.totalSupply(), 0);
        assertEq(licenseToken.totalMintedTokens(), 2);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId1));
        licenseToken.ownerOf(lcTokenId1);
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId2));
        licenseToken.ownerOf(lcTokenId2);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId3, 0);
        assertEq(licenseTemplate, address(pilTemplate));
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_parentIsChild() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner1,
            royaltyContext: ""
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIsParent.selector, ipId1));
        vm.prank(ipOwner1);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_ParentExpired() public {
        PILTerms memory expiredTerms = PILFlavors.nonCommercialSocialRemixing();
        expiredTerms.expiration = 10 days;
        uint256 expiredTermsId = pilTemplate.registerLicenseTerms(expiredTerms);

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), expiredTermsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), expiredTermsId);

        uint256 lcTokenId1 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: expiredTermsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: expiredTermsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        assertEq(licenseToken.ownerOf(lcTokenId1), ipOwner3);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId1), expiredTermsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId1), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId1), ipId1);

        assertEq(licenseToken.ownerOf(lcTokenId2), ipOwner3);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId2), expiredTermsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId2), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId2), ipId2);

        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(licenseToken.totalSupply(), 2);
        assertEq(licenseToken.balanceOf(ipOwner3), 2);

        uint256[] memory licenseTokens = new uint256[](2);
        licenseTokens[0] = lcTokenId1;
        licenseTokens[1] = lcTokenId2;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(pilTemplate), expiredTermsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId3), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipId3), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId3), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId3), 0);

        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId3);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 1);

        assertEq(licenseRegistry.hasDerivativeIps(ipId2), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), false);
        assertEq(licenseRegistry.getDerivativeIp(ipId2, 0), ipId3);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 1);

        assertEq(licenseRegistry.getParentIpCount(ipId3), 2);
        assertEq(licenseRegistry.getParentIp(ipId3, 0), ipId1);
        assertEq(licenseRegistry.getParentIp(ipId3, 1), ipId2);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId3, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, expiredTermsId);

        assertEq(licenseRegistry.getExpireTime(ipId3), block.timestamp + 10 days, "IPA has unexpected expiration time");
        vm.warp(5 days);

        uint256 lcTokenId3 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId3,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: expiredTermsId,
            amount: 1,
            receiver: ipOwner5,
            royaltyContext: ""
        });

        vm.warp(11 days);

        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId3;

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__ParentIpExpired.selector, ipId3));
        vm.prank(ipOwner5);
        licensingModule.registerDerivativeWithLicenseTokens(ipId5, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_childAlreadyAttachedLicense() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner1,
            royaltyContext: ""
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIsParent.selector, ipId1));
        vm.prank(ipOwner1);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_DerivativeIpAlreadyHasChildIp() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId2,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

        uint256 lcTokenId1 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId2;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId1;
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIpAlreadyHasChild.selector, ipId2));
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_AlreadyRegisteredAsDerivative() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId2,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

        uint256 lcTokenId1 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId1;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId2;
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeAlreadyRegistered.selector, ipId3));
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_ownedByDelegator() public {
        vm.prank(ipOwner3);
        accessController.setAllPermissions(ipId3, ipOwner2, AccessPermission.ALLOW);
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_ownedByChildIp() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipId3,
            royaltyContext: ""
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_notLicensee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseToken__CallerAndChildIPNotTokenOwner.selector,
                lcTokenId,
                ipOwner3,
                ipId3,
                ipOwner2
            )
        );
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");
    }

    function test_LicensingModule_singleTransfer_verifyOk() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });

        vm.prank(ipOwner2);
        licenseToken.transferFrom(ipOwner2, ipOwner3, lcTokenId);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId3), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipId3), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId3), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId3), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId3);
        assertEq(licenseRegistry.getParentIp(ipId3, 0), ipId1);
        assertEq(licenseRegistry.getParentIpCount(ipId3), 1);
        assertEq(licenseToken.totalSupply(), 0);
        assertEq(licenseToken.totalMintedTokens(), 1);
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        licenseToken.ownerOf(lcTokenId);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId3, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);
    }

    function test_LicensingModule_mintLicenseTokens_HookVerifyPass() public {
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);

        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(royaltyPolicyLAP),
            defaultMintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(tokenGatedHook),
            commercializerCheckerData: abi.encode(address(gatedNftBar)),
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: address(0x123),
            uri: ""
        });

        uint256 termsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        gatedNftBar.mint(ipOwner2);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });

        assertEq(licenseToken.ownerOf(lcTokenId), ipOwner2);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);
    }

    function test_LicensingModule_mintLicenseTokens_revert_HookVerifyFail() public {
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);

        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(royaltyPolicyLAP),
            defaultMintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(tokenGatedHook),
            commercializerCheckerData: abi.encode(address(gatedNftBar)),
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: address(0x123),
            uri: ""
        });

        uint256 termsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseDenyMintLicenseToken.selector,
                address(pilTemplate),
                termsId,
                ipId1
            )
        );
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });
    }

    function test_LicensingModule_revert_HookVerifyFail() public {
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);

        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(royaltyPolicyLAP),
            defaultMintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(tokenGatedHook),
            commercializerCheckerData: abi.encode(address(gatedNftBar)),
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: address(0x123),
            uri: ""
        });

        uint256 termsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 gatedNftId = gatedNftBar.mint(ipOwner2);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });
        assertEq(licenseToken.ownerOf(lcTokenId), ipOwner2);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);

        vm.prank(ipOwner2);
        gatedNftBar.burn(gatedNftId);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseTokenNotCompatibleForDerivative.selector,
                ipId2,
                licenseTokens
            )
        );
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");
    }

    // test registerDerivativeWithLicenseTokens revert licenseTokenIds is empty
    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_emptyLicenseTokens() public {
        vm.expectRevert(Errors.LicensingModule__NoLicenseToken.selector);
        vm.prank(ipOwner1);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, new uint256[](0), "");
    }

    // test registerDerivative revert parentIpIds is empty
    function test_LicensingModule_registerDerivative_revert_emptyParentIpIds() public {
        vm.expectRevert(Errors.LicensingModule__NoParentIp.selector);
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, new address[](0), new uint256[](0), address(0), "");
    }

    function test_LicensingModule_registerDerivative_revert_parentIdsLengthMismatchWithLicenseIds() public {
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        vm.expectRevert(abi.encodeWithSelector(Errors.LicensingModule__LicenseTermsLengthMismatch.selector, 1, 0));
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, new uint256[](0), address(0), "");
    }

    function test_LicensingModule_registerDerivative_revert_IncompatibleLicenses() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), socialRemixTermsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commUseTermsId);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;

        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = commUseTermsId;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__LicenseNotCompatibleForDerivative.selector, ipId3)
        );
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "");
    }

    function test_LicensingModule_registerDerivative_revert_NotAllowDerivativesReciprocal() public {
        // register license terms allow derivative but not allow derivative of derivative
        PILTerms memory terms = PILFlavors.nonCommercialSocialRemixing();
        // not allow derivative of derivative
        terms.derivativesReciprocal = false;
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);

        // register derivative
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;

        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");

        // register derivative of derivative, should revert
        parentIpIds = new address[](1);
        parentIpIds[0] = ipId2;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__LicenseNotCompatibleForDerivative.selector, ipId3)
        );
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "");
    }

    function test_LicensingModule_setLicensingConfig() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).mintingFee, 100);
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).licensingHook,
            address(licensingHook)
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).hookData,
            abi.encode(address(0x123))
        );

        vm.prank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(0), 0, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).mintingFee, 100);
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).licensingHook,
            address(licensingHook)
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).hookData,
            abi.encode(address(0x123))
        );
    }

    function test_LicensingModule_UnsetLicensingConfig() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).mintingFee, 100);
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).licensingHook,
            address(licensingHook)
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).hookData,
            abi.encode(address(0x123))
        );

        licensingConfig.isSet = false;
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).isSet, false);

        licensingConfig.isSet = true;
        vm.prank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(0), 0, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).mintingFee, 100);
        assertEq(
            licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).licensingHook,
            address(licensingHook)
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).hookData,
            abi.encode(address(0x123))
        );

        licensingConfig.isSet = false;
        vm.prank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(0), 0, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).isSet, false);
    }

    function test_LicensingModule_setLicensingConfig_revert_invalidTermsId() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__InvalidLicenseTermsId.selector, address(pilTemplate), 0)
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), 0, licensingConfig);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__InvalidLicenseTermsId.selector,
                address(0),
                socialRemixTermsId
            )
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(0), socialRemixTermsId, licensingConfig);
    }

    function test_LicensingModule_setLicensingConfig_revert_invalidLicensingHook() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        // unregistered the licensing hook
        MockLicensingHook licensingHook = new MockLicensingHook();
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__InvalidLicensingHook.selector, address(licensingHook))
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), 0, licensingConfig);

        // unsupport licensing hook interface
        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockTokenGatedHook", address(tokenGatedHook));

        licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(tokenGatedHook),
            hookData: abi.encode(address(0x123))
        });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__InvalidLicensingHook.selector, address(tokenGatedHook))
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), 0, licensingConfig);
    }

    function test_LicensingModule_setLicensingConfig_revert_paused() public {
        vm.prank(u.admin);
        licensingModule.pause();

        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
    }

    function test_LicensingModule_mintLicenseTokens_revert_licensingHookRevert() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x123);
        vm.expectRevert("MockLicensingHook: receiver is invalid");
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: ""
        });
    }

    function test_LicensingModule_calculatingMintingFee_withMintingFeeFromHook() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 999,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 999999,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x111);
        (address token, uint256 mintingFee) = licensingModule.predictMintingLicenseFee(
            ipId1,
            address(pilTemplate),
            termsId,
            5,
            receiver,
            ""
        );
        assertEq(mintingFee, 100 * 5);
        assertEq(token, address(erc20));

        address minter = vm.addr(777);
        vm.startPrank(minter);

        erc20.mint(minter, 1000);
        erc20.approve(address(royaltyModule), 100 * 5);

        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(minter, ipId1, address(pilTemplate), termsId, 5, receiver, 0);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 5,
            receiver: receiver,
            royaltyContext: ""
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(minter), 500);
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
    }

    function test_LicensingModule_calculatingMintingFee_withMintingFeeFromLicenseConfig() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 999,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 1000,
            licensingHook: address(0),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x111);
        (address token, uint256 mintingFee) = licensingModule.predictMintingLicenseFee(
            ipId1,
            address(pilTemplate),
            termsId,
            5,
            receiver,
            ""
        );
        assertEq(mintingFee, 1000 * 5);
        assertEq(token, address(erc20));

        address minter = vm.addr(777);
        vm.startPrank(minter);

        erc20.mint(minter, 5000);
        erc20.approve(address(royaltyModule), 1000 * 5);

        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(minter, ipId1, address(pilTemplate), termsId, 5, receiver, 0);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 5,
            receiver: receiver,
            royaltyContext: ""
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(minter), 0);
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
    }

    function test_LicensingModule_calculatingMintingFee_withMintingFeeFromLicense() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 10000,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x111);
        (address token, uint256 mintingFee) = licensingModule.predictMintingLicenseFee(
            ipId1,
            address(pilTemplate),
            termsId,
            5,
            receiver,
            ""
        );
        assertEq(mintingFee, 10000 * 5);
        assertEq(token, address(erc20));

        address minter = vm.addr(777);
        vm.startPrank(minter);

        erc20.mint(minter, 50000);
        erc20.approve(address(royaltyModule), 10000 * 5);

        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(minter, ipId1, address(pilTemplate), termsId, 5, receiver, 0);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 5,
            receiver: receiver,
            royaltyContext: ""
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(minter), 0);
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
    }

    function test_LicensingModule_mintLicenseTokens_withMintingFeeFromHook() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 999,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 999999,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address minter = vm.addr(777);

        vm.startPrank(minter);

        erc20.mint(minter, 1000);
        erc20.approve(address(royaltyModule), 100);

        address receiver = address(0x111);
        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(minter, ipId1, address(pilTemplate), termsId, 1, receiver, 0);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: ""
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(minter), 900);
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
    }

    function test_LicensingModule_registerDerivative_withMintingFeeFromHook() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 999,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 999999,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.startPrank(ipOwner2);
        erc20.mint(ipOwner2, 1000);
        erc20.approve(address(royaltyModule), 100);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = termsId;

        vm.expectEmit();
        emit ILicensingModule.DerivativeRegistered(
            ipOwner2,
            ipId2,
            new uint256[](0),
            parentIpIds,
            licenseTermsIds,
            address(pilTemplate)
        );
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner2), 900);
        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), true);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);
    }

    function test_LicensingModule_registerDerivative_resetToDefaultMintingFee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 300,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 999999,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.startPrank(ipOwner2);
        erc20.mint(ipOwner2, 1000);
        erc20.approve(address(royaltyModule), 100);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = termsId;

        vm.expectEmit();
        emit ILicensingModule.DerivativeRegistered(
            ipOwner2,
            ipId2,
            new uint256[](0),
            parentIpIds,
            licenseTermsIds,
            address(pilTemplate)
        );
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner2), 900);
        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), true);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);

        // reset to default minting fee
        Licensing.LicensingConfig memory licensingConfig2 = Licensing.LicensingConfig({
            isSet: false,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: abi.encode(address(0))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig2);

        vm.startPrank(ipOwner2);
        erc20.approve(address(royaltyModule), 300);
        uint256 licenseTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: ""
        });
        vm.stopPrank();
        assertEq(erc20.balanceOf(ipOwner2), 900 - 300);
        assertEq(licenseToken.ownerOf(licenseTokenId), ipOwner2);
    }

    function test_LicensingModule_registerDerivative_revert_licensingHookRevert() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(ipOwner2))
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.prank(ipOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = termsId;
        vm.prank(ipOwner2);
        vm.expectRevert("MockLicensingHook: caller is invalid");
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
