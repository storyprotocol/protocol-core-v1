// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// contracts
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
import { ILicensingModule } from "../../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { MockTokenGatedHook } from "../../mocks/MockTokenGatedHook.sol";
import { MockLicenseTemplate } from "../../mocks/module/MockLicenseTemplate.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";

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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getMintingLicenseConfig(ipId1, address(pilTemplate), termsId).isSet);
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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getMintingLicenseConfig(ipId1, address(pilTemplate), termsId).isSet);
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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId2), 0);
        assertFalse(licenseRegistry.getMintingLicenseConfig(ipId2, address(pilTemplate), termsId).isSet);
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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getMintingLicenseConfig(ipId1, address(pilTemplate), termsId1).isSet);
        assertEq(licenseRegistry.getExpireTime(ipId1), 0);
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));
        assertTrue(licenseRegistry.exists(address(pilTemplate), termsId1));

        uint256 termsId2 = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.expectEmit();
        emit ILicensingModule.LicenseTermsAttached(ipOwner1, ipId1, address(pilTemplate), termsId2);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId2);
        (address licenseTemplate2, uint256 licenseTermsId2) = licenseRegistry.getAttachedLicenseTerms(ipId1, 1);
        assertEq(licenseTemplate2, address(pilTemplate));
        assertEq(licenseTermsId2, termsId2);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId2));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 2);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 0);
        assertEq(licenseRegistry.getParentIpCount(ipId1), 0);
        assertFalse(licenseRegistry.getMintingLicenseConfig(ipId1, address(pilTemplate), termsId2).isSet);
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
            mintingFee: 0,
            expiration: 10 days,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCelling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCelling: 0,
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
        assertEq(licenseToken.getExpirationTime(lcTokenId), block.timestamp + 10 days);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 1);
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
        assertEq(licenseToken.getExpirationTime(lcTokenId), 0);
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
        assertEq(licenseToken.getExpirationTime(firstTokenId), 0);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 0), firstTokenId);

        uint256 secondTokenId = firstTokenId + 1;

        assertEq(licenseToken.ownerOf(secondTokenId), receiver);
        assertEq(licenseToken.getLicenseTermsId(secondTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(secondTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(secondTokenId), ipId1);
        assertEq(licenseToken.getExpirationTime(secondTokenId), 0);
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
            assertEq(licenseToken.getExpirationTime(tokenId), 0);
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
            mintingFee: 0,
            expiration: 10 days,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCelling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCelling: 0,
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
        assertEq(licenseToken.getExpirationTime(lcTokenId), block.timestamp + 10 days);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);
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
        assertEq(licenseToken.getExpirationTime(lcTokenId), 0);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 0), lcTokenId);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(receiver), 1);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_singleParent() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
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
        assertEq(licenseToken.getExpirationTime(lcTokenId), 0);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 1);
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
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
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
        assertEq(licenseToken.getExpirationTime(lcTokenId1), 0);

        assertEq(licenseToken.ownerOf(lcTokenId2), ipOwner3);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId2), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId2), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId2), ipId2);
        assertEq(licenseToken.getExpirationTime(lcTokenId2), 0);

        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(licenseToken.totalSupply(), 2);
        assertEq(licenseToken.balanceOf(ipOwner3), 2);

        uint256[] memory licenseTokens = new uint256[](2);
        licenseTokens[0] = lcTokenId1;
        licenseTokens[1] = lcTokenId2;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId3), 1);
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

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_ExpiredLicenseToken() public {
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);
        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(royaltyPolicyLAP),
            mintingFee: 0,
            expiration: 10 days,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCelling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCelling: 0,
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

        uint256 lcTokenExpiredTime = licenseToken.getExpirationTime(lcTokenId);
        assertEq(licenseToken.ownerOf(lcTokenId), ipOwner2);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(lcTokenExpiredTime, block.timestamp + 10 days);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(ipOwner2), 1);

        vm.warp(11 days);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseToken__LicenseTokenExpired.selector,
                lcTokenId,
                lcTokenExpiredTime,
                block.timestamp
            )
        );
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_ParentExpired() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        PILTerms memory expiredTerms = PILFlavors.nonCommercialSocialRemixing();
        expiredTerms.expiration = 10 days;
        uint256 expiredTermsId = pilTemplate.registerLicenseTerms(expiredTerms);

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), expiredTermsId);

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
            licenseTermsId: expiredTermsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: ""
        });

        assertEq(licenseToken.ownerOf(lcTokenId1), ipOwner3);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId1), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId1), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId1), ipId1);
        assertEq(licenseToken.getExpirationTime(lcTokenId1), 0);

        assertEq(licenseToken.ownerOf(lcTokenId2), ipOwner3);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId2), expiredTermsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId2), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId2), ipId2);
        assertEq(licenseToken.getExpirationTime(lcTokenId2), block.timestamp + 10 days);

        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(licenseToken.totalSupply(), 2);
        assertEq(licenseToken.balanceOf(ipOwner3), 2);

        uint256[] memory licenseTokens = new uint256[](2);
        licenseTokens[0] = lcTokenId1;
        licenseTokens[1] = lcTokenId2;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(pilTemplate), termsId), true);
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
        assertEq(licenseTermsId, termsId);
        (address anotherLicenseTemplate, uint256 anotherLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
            ipId3,
            1
        );
        assertEq(anotherLicenseTemplate, address(pilTemplate));
        assertEq(anotherLicenseTermsId, expiredTermsId);
        uint256[] memory licenseTerms = new uint256[](2);
        licenseTerms[0] = termsId;
        licenseTerms[1] = expiredTermsId;

        assertEq(licenseRegistry.getExpireTime(ipId3), block.timestamp + 10 days, "IPA has unexpected expiration time");
        vm.warp(5 days);

        uint256 lcTokenId3 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId3,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
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

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense.selector, ipId1));
        vm.prank(ipOwner1);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, licenseTokens, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_AlreadyRegisteredAsDerivative() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
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

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_notLicensee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
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

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseToken__NotLicenseTokenOwner.selector, lcTokenId, ipOwner3, ipOwner2)
        );
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");
    }

    function test_LicensingModule_singleTransfer_verifyOk() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
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

        vm.prank(ipOwner2);
        licenseToken.transferFrom(ipOwner2, ipOwner3, lcTokenId);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId3), 1);
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
            mintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(tokenGatedHook),
            commercializerCheckerData: abi.encode(address(gatedNftBar)),
            commercialRevShare: 0,
            commercialRevCelling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCelling: 0,
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
        assertEq(licenseToken.getExpirationTime(lcTokenId), 0);
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
            mintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(tokenGatedHook),
            commercializerCheckerData: abi.encode(address(gatedNftBar)),
            commercialRevShare: 0,
            commercialRevCelling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCelling: 0,
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
            mintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(tokenGatedHook),
            commercializerCheckerData: abi.encode(address(gatedNftBar)),
            commercialRevShare: 0,
            commercialRevCelling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCelling: 0,
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
        assertEq(licenseToken.getExpirationTime(lcTokenId), 0);
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

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
