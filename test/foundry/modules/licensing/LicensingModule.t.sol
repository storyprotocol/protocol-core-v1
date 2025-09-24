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
import { MockIPGraph } from "../../mocks/MockIPGraph.sol";
import { MockLicenseTemplate } from "../../mocks/module/MockLicenseTemplate.sol";
import { MockLicensingHook } from "../../mocks/module/MockLicensingHook.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { Licensing } from "../../../../contracts/lib/Licensing.sol";
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "../../../../contracts/lib/AccessPermission.sol";

// test
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract MockIPGraphDiamond is MockIPGraph {
    address internal ipId1;
    address internal ipId2;
    address internal ipId3;
    mapping(address => uint256) internal ancestorsCount;

    function initialize(address ipId1_, address ipId2_, address ipId3_) external {
        ipId1 = ipId1_;
        ipId2 = ipId2_;
        ipId3 = ipId3_;
    }

    function setAncestorsCount(address ipId, uint256 count) external {
        ancestorsCount[ipId] = count;
    }

    function getAncestorIpsCount(address ipId) external virtual override returns (uint256) {
        return ancestorsCount[ipId];
    }

    function _getRoyaltyLrp(address ipId, address ancestorIpId) internal override returns (uint256 result) {
        if (ipId == ipId1 && ancestorIpId == ipId2) {
            return 50_000_000;
        } else if (ipId == ipId1 && ancestorIpId == ipId3) {
            return 75_000_000;
        } else if (ipId == ipId2 && ancestorIpId == ipId3) {
            return 50_000_000;
        }
        return 0;
    }
}

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
        bytes32 ipId1State = IIPAccount(payable(ipId1)).state();
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        assertNotEq(ipId1State, IIPAccount(payable(ipId1)).state());
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, termsId);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);
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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);
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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 1);
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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);
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
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 2);
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);

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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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

    function test_LicensingModule_mintLicenseTokens_EqualsMaxMintingFee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10_000_000,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.startPrank(ipOwner2);
        erc20.mint(ipOwner2, 1000);
        erc20.approve(address(royaltyModule), 100);

        address receiver = address(0x111);
        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(ipOwner2, ipId1, address(pilTemplate), termsId, 1, receiver, 0);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: "",
            maxMintingFee: 100,
            maxRevenueShare: 0
        });
        vm.stopPrank();
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 0), lcTokenId);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(receiver), 1);
    }

    function test_LicensingModule_mintLicenseTokens_LessThanMaxMintingFee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10_000_000,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.startPrank(ipOwner2);
        erc20.mint(ipOwner2, 1000);
        erc20.approve(address(royaltyModule), 100);

        address receiver = address(0x111);
        vm.expectEmit();
        emit ILicensingModule.LicenseTokensMinted(ipOwner2, ipId1, address(pilTemplate), termsId, 1, receiver, 0);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: "",
            maxMintingFee: 1000,
            maxRevenueShare: 0
        });
        vm.stopPrank();
        assertEq(erc20.balanceOf(ipOwner2), 900);
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), termsId);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.tokenOfOwnerByIndex(receiver, 0), lcTokenId);
        assertEq(licenseToken.totalMintedTokens(), 1);
        assertEq(licenseToken.totalSupply(), 1);
        assertEq(licenseToken.balanceOf(receiver), 1);

        // check licensor IP received the minting fee
        address licensorRoyaltyVault = royaltyModule.ipRoyaltyVaults(ipId1);
        assertEq(erc20.balanceOf(licensorRoyaltyVault), 100);
    }

    function test_LicensingModule_revert_mintLicenseTokens_ExceededMaxMintingFee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 1000,
                commercialRevShare: 10_000_000,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.startPrank(ipOwner2);
        erc20.mint(ipOwner2, 1000);
        erc20.approve(address(royaltyModule), 1000);

        address receiver = address(0x111);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__MintingFeeExceedMaxMintingFee.selector, 1000, 100)
        );
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: receiver,
            royaltyContext: "",
            maxMintingFee: 100,
            maxRevenueShare: 0
        });
        vm.stopPrank();
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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

    function test_LicensingModule_revert_mintLicenseTokens_mintMultipleTokens_ExceededMaxMintingFee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 1000,
                commercialRevShare: 10_000_000,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.startPrank(ipOwner2);
        erc20.mint(ipOwner2, 2000);
        erc20.approve(address(royaltyModule), 2000);

        address receiver = address(0x111);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__MintingFeeExceedMaxMintingFee.selector, 2000, 1500)
        );
        uint256 firstTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 2,
            receiver: receiver,
            royaltyContext: "",
            maxMintingFee: 1500,
            maxRevenueShare: 0
        });
    }

    function test_LicensingModule_revert_registerDerivative_singleParent_ExceedMaxRevenueShare() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 500,
                commercialRevShare: 10_000_000,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 500);
        erc20.approve(address(royaltyModule), 500);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__ExceedMaxRevenueShare.selector,
                ipId1,
                address(pilTemplate),
                commRemixTermsId,
                10_000_000,
                5_000_000
            )
        );
        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 500,
            maxRts: 100e6,
            maxRevenueShare: 5_000_000
        });
        vm.stopPrank();
    }

    function test_LicensingModule_registerDerivative_singleParent_LessThanMaxMintingFee() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 500,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 500);
        erc20.approve(address(royaltyModule), 500);

        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 600, // maxMintingFee = 600 > 500 = mintingFee
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner5), 0);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 500);
        assertEq(licenseRegistry.getParentIp(ipId5, 0), ipId1);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId5, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
    }

    function test_LicensingModule_registerDerivative_multipleParents_LessThanMaxMintingFee() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](3);
        uint256[] memory licenseTermsIds = new uint256[](3);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        parentIpIds[2] = ipId3;
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        licenseTermsIds[2] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 600);
        erc20.approve(address(royaltyModule), 600);

        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 1_000, // maxMintingFee = 1_000 > 600 = 200 * 3 = total minting fee
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner5), 0);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 200);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId2)), 200);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId3)), 200);
        assertEq(licenseRegistry.getParentIp(ipId5, 0), ipId1);
        assertEq(licenseRegistry.getParentIp(ipId5, 1), ipId2);
        assertEq(licenseRegistry.getParentIp(ipId5, 2), ipId3);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId5, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
    }

    function test_LicensingModule_registerDerivative_singleParent_EqualsMaxMintingFee() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 500,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 500);
        erc20.approve(address(royaltyModule), 500);

        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 500, // maxMintingFee = 500 = mintingFee
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner5), 0);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 500);
        assertEq(licenseRegistry.getParentIp(ipId5, 0), ipId1);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId5, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
    }

    function test_LicensingModule_registerDerivative_multipleParents_EqualsMaxMintingFee() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](3);
        uint256[] memory licenseTermsIds = new uint256[](3);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        parentIpIds[2] = ipId3;
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        licenseTermsIds[2] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 600);
        erc20.approve(address(royaltyModule), 600);

        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 600, // maxMintingFee = 600 = 200 * 3 = total minting fee
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner5), 0);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 200);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId2)), 200);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId3)), 200);
        assertEq(licenseRegistry.getParentIp(ipId5, 0), ipId1);
        assertEq(licenseRegistry.getParentIp(ipId5, 1), ipId2);
        assertEq(licenseRegistry.getParentIp(ipId5, 2), ipId3);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId5, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
    }

    function test_LicensingModule_registerDerivative_singleParent_EqualsMaxRevenueShare() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 500,
                commercialRevShare: 10_000_000,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 500);
        erc20.approve(address(royaltyModule), 500);

        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 500,
            maxRts: 100e6,
            maxRevenueShare: 10_000_000 // maxRevenueShare = 10_000_000 = commercialRevShare
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner5), 0);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 500);
        assertEq(licenseRegistry.getParentIp(ipId5, 0), ipId1);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId5, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
    }

    function test_LicensingModule_registerDerivative_multipleParents_EqualsMaxRevenueShare() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 10_000_000,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](3);
        uint256[] memory licenseTermsIds = new uint256[](3);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        parentIpIds[2] = ipId3;
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        licenseTermsIds[2] = commRemixTermsId;

        bytes32 ipId5State = IIPAccount(payable(ipId5)).state();
        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 600);
        erc20.approve(address(royaltyModule), 600);
        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 600,
            maxRts: 100e6,
            maxRevenueShare: 30_000_000 // maxRevenueShare = 30_000_000 = commercialRevShare * 3
        });
        vm.stopPrank();
        assertNotEq(ipId5State, IIPAccount(payable(ipId5)).state());

        assertEq(erc20.balanceOf(ipOwner5), 0);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 200);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId2)), 200);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId3)), 200);
        assertEq(licenseRegistry.getParentIp(ipId5, 0), ipId1);
        assertEq(licenseRegistry.getParentIp(ipId5, 1), ipId2);
        assertEq(licenseRegistry.getParentIp(ipId5, 2), ipId3);
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId5, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
    }

    function test_LicensingModule_revert_registerDerivative_multipleParents_ExceedMaxRevShare_DirectOvershoot() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 10_000_000,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](3);
        uint256[] memory licenseTermsIds = new uint256[](3);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        parentIpIds[2] = ipId3;
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        licenseTermsIds[2] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 600);
        erc20.approve(address(royaltyModule), 600);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__ExceedMaxRevenueShare.selector,
                ipId3,
                address(pilTemplate),
                commRemixTermsId,
                30_000_000,
                25_000_000 // maxRevenueShare
            )
        );
        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 600,
            maxRts: 100e6,
            maxRevenueShare: 25_000_000
        });
        vm.stopPrank();
    }

    function test_LicensingModule_revert_registerDerivative_multipleParents_ExceedMaxRevShare_BoundaryCondition()
        public
    {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 10_000_000,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](3);
        uint256[] memory licenseTermsIds = new uint256[](3);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        parentIpIds[2] = ipId3;
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        licenseTermsIds[2] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 600);
        erc20.approve(address(royaltyModule), 600);

        // boundary conditions:
        // accumulated revenue share: 10M(10%), 20M(20%), 30M(30%)
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__ExceedMaxRevenueShare.selector,
                ipId3,
                address(pilTemplate),
                commRemixTermsId,
                30_000_000,
                20_000_000 // maxRevenueShare
            )
        );
        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 600,
            maxRts: 100e6,
            maxRevenueShare: 20_000_000
        });
        vm.stopPrank();
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
                royaltyContext: "",
                maxMintingFee: 0,
                maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        vm.expectRevert(Errors.LicensingModule__ReceiverZeroAddress.selector);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: address(0),
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);

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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), termsId), false);

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

    function test_LicensingModule_mintLicenseToken_revert_privateLicenseTemplateIsDifferentFromExisting() public {
        uint256 termsId1 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLRP)
            })
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId1);

        MockLicenseTemplate pilTemplate2 = new MockLicenseTemplate();
        vm.prank(admin);
        licenseRegistry.registerLicenseTemplate(address(pilTemplate2));
        uint256 termsId2 = pilTemplate2.registerLicenseTerms();

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__UnmatchedLicenseTemplate.selector,
                ipId1,
                address(pilTemplate),
                address(pilTemplate2)
            )
        );
        vm.prank(ipOwner1);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate2),
            licenseTermsId: termsId2,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_LicensingModule_attachLicenseTerms_revert_templateDifferentFromPrivateLicenseTemplate() public {
        uint256 termsId1 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLRP)
            })
        );
        vm.prank(ipOwner1);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId1,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        MockLicenseTemplate pilTemplate2 = new MockLicenseTemplate();
        vm.prank(admin);
        licenseRegistry.registerLicenseTemplate(address(pilTemplate2));
        uint256 termsId2 = pilTemplate2.registerLicenseTerms();

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__UnmatchedLicenseTemplate.selector,
                ipId1,
                address(pilTemplate),
                address(pilTemplate2)
            )
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate2), termsId2);
    }

    function test_LicensingModule_attachLicenseTerms_templateSameWithPrivateLicenseTemplate() public {
        uint256 termsId1 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLRP)
            })
        );
        vm.prank(ipOwner1);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId1,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256 termsId2 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId2);
    }

    function test_LicensingModule_mintLicenseToken_PrivateLicenseTemplateSameWithExisting() public {
        uint256 termsId1 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLRP)
            })
        );

        uint256 termsId2 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId1);

        bytes32 ipId1State = IIPAccount(payable(ipId1)).state();
        vm.prank(ipOwner1);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId2,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        assertNotEq(
            ipId1State,
            IIPAccount(payable(ipId1)).state(),
            "IP state should change after minting private license token"
        );
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        vm.prank(u.admin);
        licensingModule.pause();

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);

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
        licensingModule.attachDefaultLicenseTerms(ipId1);
        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseToken__ChildIPAlreadyHasBeenMintedLicenseTokens.selector, ipId1)
        );
        vm.prank(ipOwner1);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, licenseTokens, "", 100e6);
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: expiredTermsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(pilTemplate), expiredTermsId), true);
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        vm.warp(11 days);

        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId3;

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__ParentIpExpired.selector, ipId3));
        vm.prank(ipOwner5);
        licensingModule.registerDerivativeWithLicenseTokens(ipId5, licenseTokens, "", 100e6);
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
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.prank(ipOwner2);
        licensingModule.attachDefaultLicenseTerms(ipId2);

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense.selector, ipId2));
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_DerivativeIpAlreadyHasChildIp() public {
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
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId2;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);

        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId1;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseToken__ChildIPAlreadyHasBeenMintedLicenseTokens.selector, ipId2)
        );
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId1;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);

        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId2;
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeAlreadyRegistered.selector, ipId3));
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_royaltyPolicyMismatch() public {
        PILTerms memory terms = PILFlavors.commercialRemix({
            mintingFee: 0,
            commercialRevShare: 10,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(erc20)
        });
        terms.derivativesReciprocal = false;

        uint256 termsIdLAP = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsIdLAP);

        terms.royaltyPolicy = address(royaltyPolicyLRP);
        uint256 termsIdLRP = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsIdLRP);

        uint256 lcTokenId1 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsIdLAP,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256 lcTokenId2 = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsIdLRP,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](2);
        licenseTokens[0] = lcTokenId1;
        licenseTokens[1] = lcTokenId2;
        vm.prank(ipOwner3);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__RoyaltyPolicyMismatch.selector,
                address(royaltyPolicyLAP),
                address(royaltyPolicyLRP)
            )
        );
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_mintPrivateLicense() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10_000_000,
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(erc20)
            })
        );
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens(
            ipId1,
            address(pilTemplate),
            commRemixTermsId,
            1,
            ipOwner2,
            "",
            0,
            0
        );

        vm.prank(ipOwner2);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseToken__ChildIPAlreadyHasBeenMintedLicenseTokens.selector, ipId2)
        );
        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);
    }

    function test_LicensingModule_registerDerivative_revert_royaltyPolicyMismatch() public {
        PILTerms memory terms = PILFlavors.commercialRemix({
            mintingFee: 0,
            commercialRevShare: 10,
            royaltyPolicy: address(royaltyPolicyLAP),
            currencyToken: address(erc20)
        });
        terms.derivativesReciprocal = false;

        uint256 termsIdLAP = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsIdLAP);

        terms.royaltyPolicy = address(royaltyPolicyLRP);
        uint256 termsIdLRP = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsIdLRP);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;

        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = termsIdLAP;
        licenseTermsIds[1] = termsIdLRP;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__RoyaltyPolicyMismatch.selector,
                address(royaltyPolicyLAP),
                address(royaltyPolicyLRP)
            )
        );
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_registerDerivative_revert_singleParent_ExceedMaxMintingFee() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 500,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 500);
        erc20.approve(address(royaltyModule), 500);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__MintingFeeExceedMaxMintingFee.selector, 500, 200)
        );
        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 200,
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();
    }

    function test_LicensingModule_registerDerivative_revert_multipleParents_ExceedMaxMintingFee_BoundaryCondition()
        public
    {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](3);
        uint256[] memory licenseTermsIds = new uint256[](3);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        parentIpIds[2] = ipId3;
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        licenseTermsIds[2] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 600);
        erc20.approve(address(royaltyModule), 600);

        // boundary conditions:
        // accumulated minting fee: 200, 400, 600
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__MintingFeeExceedMaxMintingFee.selector, 600, 400)
        );
        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 400,
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();
    }

    function test_LicensingModule_registerDerivative_revert_multipleParents_ExceedMaxMintingFee_DirectOvershoot()
        public
    {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](3);
        uint256[] memory licenseTermsIds = new uint256[](3);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        parentIpIds[2] = ipId3;
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        licenseTermsIds[2] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 600);
        erc20.approve(address(royaltyModule), 600);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__MintingFeeExceedMaxMintingFee.selector, 600, 500)
        );
        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 500,
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_ownedByDelegator() public {
        vm.prank(ipOwner3);
        accessController.setAllPermissions(ipId3, ipOwner2, AccessPermission.ALLOW);
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);

        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        vm.prank(ipOwner2);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_ownedByChildIp() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        uint256 lcTokenId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: termsId,
            amount: 1,
            receiver: ipId3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        bytes32 ipId3State = IIPAccount(payable(ipId3)).state();
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);
        assertNotEq(ipId3State, IIPAccount(payable(ipId3)).state(), "Child IP state should be changed");
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        vm.prank(ipOwner2);
        licenseToken.transferFrom(ipOwner2, ipOwner3, lcTokenId);

        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;
        vm.prank(ipOwner3);
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "", 100e6);

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
        vm.prank(u.admin);
        moduleRegistry.registerModule("MockTokenGatedHook", address(tokenGatedHook));

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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        vm.prank(u.admin);
        moduleRegistry.registerModule("MockTokenGatedHook", address(tokenGatedHook));

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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_LicensingModule_revert_HookVerifyFail() public {
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);

        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        vm.prank(u.admin);
        moduleRegistry.registerModule("MockTokenGatedHook", address(tokenGatedHook));

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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseTokens, "", 100e6);
    }

    // test registerDerivativeWithLicenseTokens revert licenseTokenIds is empty
    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_emptyLicenseTokens() public {
        vm.expectRevert(Errors.LicensingModule__NoLicenseToken.selector);
        vm.prank(ipOwner1);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, new uint256[](0), "", 100e6);
    }

    // test registerDerivative revert parentIpIds is empty
    function test_LicensingModule_registerDerivative_revert_emptyParentIpIds() public {
        vm.expectRevert(Errors.LicensingModule__NoParentIp.selector);
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, new address[](0), new uint256[](0), address(0), "", 0, 100e6, 0);
    }

    function test_LicensingModule_registerDerivative_revert_parentIdsLengthMismatchWithLicenseIds() public {
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        vm.expectRevert(abi.encodeWithSelector(Errors.LicensingModule__LicenseTermsLengthMismatch.selector, 1, 0));
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, new uint256[](0), address(0), "", 0, 100e6, 0);
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
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_registerDerivative_revert_mintPrivateLicense() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10_000_000,
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(erc20)
            })
        );
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        vm.prank(ipOwner2);
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId,
            amount: 1,
            receiver: ipOwner3,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commRemixTermsId;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__DerivativeAlreadyHasBeenMintedLicenseTokens.selector, ipId2)
        );
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_registerDerivative_revert_CommercialUseOnlyLicense() public {
        (, uint256 defaultTermsId) = licenseRegistry.getDefaultLicenseTerms();
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commUseTermsId);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;

        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = defaultTermsId;
        licenseTermsIds[1] = commUseTermsId;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__LicenseNotCompatibleForDerivative.selector, ipId3)
        );
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
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
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);

        // register derivative of derivative, should revert
        parentIpIds = new address[](1);
        parentIpIds[0] = ipId2;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__LicenseNotCompatibleForDerivative.selector, ipId3)
        );
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_setLicensingConfig() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).mintingFee, 0);
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).licensingHook,
            address(licensingHook)
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).hookData,
            abi.encode(address(0x123))
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).commercialRevShare,
            0
        );

        vm.prank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).mintingFee, 0);
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).licensingHook,
            address(licensingHook)
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).hookData,
            abi.encode(address(0x123))
        );
    }

    function test_LicensingModule_setLicensingConfigWithRoyaltyPercent() public {
        uint256 commercialRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 1000,
                commercialRevShare: 1_000_000,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 1000,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 10_000_000,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commercialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), commercialRemixTermsId).isSet, true);
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), commercialRemixTermsId).mintingFee,
            1000
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), commercialRemixTermsId).licensingHook,
            address(licensingHook)
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), commercialRemixTermsId).hookData,
            abi.encode(address(0x123))
        );
        assertEq(
            licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), commercialRemixTermsId).commercialRevShare,
            10_000_000
        );
    }

    function test_LicensingModule_DerivativeModifyRoyaltyPercent() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 1_000_000,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );

        // attach commercial remix terms
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = termsId;
        // register derivative
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10_000_000,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.prank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), termsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), termsId).mintingFee, 0);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), termsId).licensingHook, address(0));
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), termsId).hookData, "");
        assertEq(
            licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), termsId).commercialRevShare,
            10_000_000
        );

        parentIpIds = new address[](1);
        parentIpIds[0] = ipId2;
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);

        erc20.mint(ipOwner3, 1000);
        vm.startPrank(ipOwner3);
        erc20.approve(address(royaltyModule), 1000);
        royaltyModule.payRoyaltyOnBehalf(ipId3, address(0), address(erc20), 1000);
        royaltyPolicyLAP.transferToVault(ipId3, ipId2, address(erc20));
        royaltyPolicyLAP.transferToVault(ipId3, ipId1, address(erc20));
        vm.stopPrank();
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId2)), 100);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 10);
    }

    function test_LicensingModule_UnsetLicensingConfig() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId).mintingFee, 0);
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
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).isSet, true);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).mintingFee, 0);
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
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId, licensingConfig);
        assertEq(licenseRegistry.getLicensingConfig(ipId2, address(pilTemplate), socialRemixTermsId).isSet, false);
    }

    function test_LicensingModule_setLicensingConfig_revert_MintingFeeRequiresRoyaltyPolicy() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILTerms({
                transferable: true,
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
                derivativesApproval: true,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: address(0),
                uri: ""
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.expectRevert(Errors.LicensingModule__MintingFeeRequiresRoyaltyPolicy.selector);
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
    }

    function test_LicensingModule_setLicensingConfig_revert_invalidTermsId() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__InvalidLicenseTermsId.selector, address(pilTemplate), 0)
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), 0, licensingConfig);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__InvalidLicenseTermsId.selector, address(pilTemplate), 0)
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), 0, licensingConfig);
    }

    function test_LicensingModule_setLicensingConfig_revert_InvalidRoyaltyPercentConfig() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 1000,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseRegistry__UnregisteredLicenseTemplate.selector, address(0x123))
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(0x123), 1, licensingConfig);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__CurrentLicenseNotAllowOverrideRoyaltyPercent.selector,
                address(pilTemplate),
                socialRemixTermsId,
                1000
            )
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
    }

    function test_LicensingModule_setLicensingConfig_revert_newRoyaltyPercentLessThanLicenseTerms() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20_000_000,
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(erc20)
            })
        );
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 10_000_000,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__CurrentLicenseNotAllowOverrideRoyaltyPercent.selector,
                address(pilTemplate),
                commRemixTermsId,
                10_000_000
            )
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commRemixTermsId, licensingConfig);
    }

    function test_LicensingModule_setLicensingConfig_revert_invalidLicensingHook() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        // unregistered the licensing hook
        MockLicensingHook licensingHook = new MockLicensingHook();
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__InvalidLicensingHook.selector, address(licensingHook))
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);

        // unsupport licensing hook interface
        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockTokenGatedHook", address(tokenGatedHook));

        licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(tokenGatedHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__InvalidLicensingHook.selector, address(tokenGatedHook))
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), socialRemixTermsId, licensingConfig);
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
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
            mintingFee: 0,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_LicensingModule_mintLicenseTokens_revert_licenseDisabled() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 0,
            disabled: true,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address receiver = address(0x123);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseDisabled.selector,
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_LicensingModule_mintLicenseToken_revert_OverMaxAncestorsLimit() public {
        uint256 maxAncestors = 1024;

        vm.etch(address(0x0101), address(new MockIPGraphDiamond()).code);
        MockIPGraphDiamond(address(0x0101)).setAncestorsCount(ipId1, maxAncestors);

        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix(0, 10, address(royaltyPolicyLAP), address(erc20))
        );

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__TooManyAncestorsForMintingLicenseTokenAllowRegisterDerivative.selector,
                ipId1,
                maxAncestors,
                licenseRegistry.MAX_ANCESTORS()
            )
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_LicensingModule_calculatingMintingFee_withMintingFeeFromHook() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
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
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(minter), 0);
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
    }

    function test_LicensingModule_mintLicenseTokens_withMintingFeeFromHook() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
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
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        vm.stopPrank();

        assertEq(erc20.balanceOf(minter), 900);
        assertEq(licenseToken.ownerOf(lcTokenId), receiver);
    }

    function test_LicensingModule_registerDerivative_withMintingFeeFromHook() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
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
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner2), 900);
        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), true);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);
    }

    function test_LicensingModule_registerDerivative_resetToDefaultMintingFee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
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
            hookData: abi.encode(address(0x123)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
        vm.stopPrank();

        assertEq(erc20.balanceOf(ipOwner2), 900);
        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), termsId), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId2), true);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);

        // reset to default minting fee
        Licensing.LicensingConfig memory licensingConfig2 = Licensing.LicensingConfig({
            isSet: false,
            mintingFee: 300,
            licensingHook: address(0),
            hookData: abi.encode(address(0)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
        vm.stopPrank();
        assertEq(erc20.balanceOf(ipOwner2), 900 - 100);
        assertEq(licenseToken.ownerOf(licenseTokenId), ipOwner2);
    }

    function test_LicensingModule_registerDerivative_revert_licensingHookRevert() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(ipOwner2)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = termsId;
        vm.prank(ipOwner2);
        vm.expectRevert("MockLicensingHook: caller is invalid");
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_registerDerivative_revert_licenseDisabled() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 0,
            disabled: true,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });
        vm.startPrank(ipOwner1);
        licensingModule.attachDefaultLicenseTerms(ipId1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = termsId;
        vm.prank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseDisabled.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_registerDerivative_revert_IpAlreadyHasDerivative() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 500,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = commRemixTermsId;

        vm.startPrank(ipOwner5);
        erc20.mint(ipOwner5, 500);
        erc20.approve(address(royaltyModule), 500);

        licensingModule.registerDerivative({
            childIpId: ipId5,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 600, // maxMintingFee = 600 > 500 = mintingFee
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();

        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);
        address[] memory parentIpIds2 = new address[](1);
        uint256[] memory licenseTermsIds2 = new uint256[](1);
        parentIpIds2[0] = ipId2;
        licenseTermsIds2[0] = commRemixTermsId;

        vm.startPrank(ipOwner1);
        erc20.mint(ipOwner1, 500);
        erc20.approve(address(royaltyModule), 500);

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIpAlreadyHasChild.selector, ipId1));
        licensingModule.registerDerivative({
            childIpId: ipId1,
            parentIpIds: parentIpIds2,
            licenseTermsIds: licenseTermsIds2,
            licenseTemplate: address(pilTemplate),
            royaltyContext: "",
            maxMintingFee: 600, // maxMintingFee = 600 > 500 = mintingFee
            maxRts: 100e6,
            maxRevenueShare: 0
        });
        vm.stopPrank();
    }

    function test_LicensingModule_registerDerivative_payRoyaltyMultipleLevels() public {
        vm.etch(address(0x0101), address(new MockIPGraphDiamond()).code);
        MockIPGraphDiamond(address(0x0101)).initialize(ipId1, ipId2, ipId3);

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 50_000_000,
                royaltyPolicy: address(royaltyPolicyLRP),
                currencyToken: address(erc20)
            })
        );

        vm.prank(ipOwner3);
        licensingModule.attachLicenseTerms(ipId3, address(pilTemplate), termsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId3;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = termsId;

        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 50_000_000,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.prank(ipOwner2);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);

        vm.prank(ipOwner3);
        licensingModule.setLicensingConfig(ipId3, address(pilTemplate), termsId, licensingConfig);

        parentIpIds = new address[](2);
        parentIpIds[1] = ipId2;
        parentIpIds[0] = ipId3;
        licenseTermsIds = new uint256[](2);
        licenseTermsIds[1] = termsId;
        licenseTermsIds[0] = termsId;

        vm.prank(ipOwner1);
        licensingModule.registerDerivative(ipId1, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);

        assertEq(MockIPGraphDiamond(address(0x0101)).getParentIpsCount(ipId1), 2);

        address revenueCollector = address(0x999);
        vm.startPrank(revenueCollector);
        erc20.mint(revenueCollector, 1000);
        erc20.approve(address(royaltyModule), 1000);

        assertEq(erc20.balanceOf(address(royaltyPolicyLRP)), 0);

        royaltyModule.payRoyaltyOnBehalf(ipId1, address(0), address(erc20), 1000);

        assertEq(erc20.balanceOf(revenueCollector), 0);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 0);

        royaltyPolicyLRP.transferToVault(ipId1, ipId3, address(erc20));

        royaltyPolicyLRP.transferToVault(ipId1, ipId2, address(erc20));
        vm.stopPrank();

        assertEq(royaltyPolicyLRP.getPolicyRoyaltyStack(ipId1), 100_000_000);
        assertEq(royaltyPolicyLRP.getPolicyRoyaltyStack(ipId2), 50_000_000);
        assertEq(royaltyPolicyLRP.getPolicyRoyaltyStack(ipId3), 0);

        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId2)), 250);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId3)), 750);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 0);
        assertEq(erc20.balanceOf(address(royaltyPolicyLRP)), 0);
    }

    function test_LicensingModule_registerDerivative_revert_noDefaultLicenseAttached() public {
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) = licenseRegistry.getDefaultLicenseTerms();

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = defaultLicenseTermsId;
        vm.prank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__ParentIpUnmatchedLicenseTemplate.selector,
                ipId1,
                address(pilTemplate)
            )
        );
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_setLicensingConfig_revert_ConfigMintingFeeLessThanDefaultMintingFee() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 300,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 200, // Set lower than default minting fee of 300
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicensingConfigMintingFeeBelowLicenseTerms.selector,
                address(pilTemplate),
                termsId,
                200,
                300
            )
        );
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
    }

    function test_LicensingModule_setLicensingConfig_revert_ZeroLicenseTemplate() public {
        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.expectRevert(Errors.LicensingModule__ZeroLicenseTemplate.selector);
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(0), 0, licensingConfig);

        vm.expectRevert(Errors.LicensingModule__ZeroLicenseTemplate.selector);
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(0), 1, licensingConfig);
    }

    function test_LicensingModule_mintLicenseTokens_revert_LicensingHookMintingFeeBelowLicenseTerms() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 300,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 400,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commRemixTermsId, licensingConfig);

        vm.prank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__LicensingHookMintingFeeBelowLicenseTerms.selector, 100, 300)
        );
        licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            amount: 1,
            receiver: ipOwner2,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_LicensingModule_registerDerivative_revert_LicensingHookMintingFeeBelowLicenseTerms() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 300,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 400,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commRemixTermsId, licensingConfig);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commRemixTermsId;
        vm.prank(ipOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicensingModule__LicensingHookMintingFeeBelowLicenseTerms.selector, 100, 300)
        );
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6, 0);
    }

    function test_LicensingModule_predictMintingLicenseFee_LicensingHookMintingFeeBelowLicenseTerms() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 300,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        MockLicensingHook licensingHook = new MockLicensingHook();
        vm.prank(admin);
        moduleRegistry.registerModule("MockLicensingHook", address(licensingHook));

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 400,
            licensingHook: address(licensingHook),
            hookData: abi.encode(address(0)),
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), commRemixTermsId, licensingConfig);

        vm.prank(ipOwner2);
        (address currencyToken, uint256 amount) = licensingModule.predictMintingLicenseFee(
            ipId1,
            address(pilTemplate),
            commRemixTermsId,
            1,
            ipOwner2,
            ""
        );
        assertEq(currencyToken, address(erc20));
        assertEq(
            amount,
            100 // the minting fee from licensing hook
        );
    }

    function test_LicensingModule_attachDefaultLicenseTerms_revert_NoPermission() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipId1),
                ipOwner2,
                address(licensingModule),
                ILicensingModule.attachDefaultLicenseTerms.selector
            )
        );
        vm.prank(ipOwner2);
        licensingModule.attachDefaultLicenseTerms(ipId1);

        // Verify that the IP owner can attach default license terms
        vm.prank(ipOwner1);
        licensingModule.attachDefaultLicenseTerms(ipId1);
    }

    function test_LicensingModule_attachDefaultLicenseTerms_withPermission() public {
        // Test that an unauthorized user cannot attach default license terms to ipId3
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipId3),
                ipOwner1,
                address(licensingModule),
                ILicensingModule.attachDefaultLicenseTerms.selector
            )
        );
        vm.prank(ipOwner1);
        licensingModule.attachDefaultLicenseTerms(ipId3);

        // Grant permission to ipOwner1 to attach default license terms to ipId3
        vm.prank(ipOwner3);
        accessController.setPermission(
            ipId3,
            ipOwner1,
            address(licensingModule),
            ILicensingModule.attachDefaultLicenseTerms.selector,
            AccessPermission.ALLOW
        );

        // Verify that an authorized operator can attach default license terms to ipId3
        vm.prank(ipOwner1);
        licensingModule.attachDefaultLicenseTerms(ipId3);
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
