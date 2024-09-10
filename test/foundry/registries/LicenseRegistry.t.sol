// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// contracts
import { IIPAccount } from "../../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../contracts/lib/PILFlavors.sol";
import { MockLicenseTemplate } from "../mocks/module/MockLicenseTemplate.sol";
import { IPAccountStorageOps } from "../../../contracts/lib/IPAccountStorageOps.sol";
import { Licensing } from "../../../contracts/lib/Licensing.sol";
import { PILTerms } from "../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";

// test
import { MockERC721 } from "../mocks/token/MockERC721.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";
import { LicenseRegistryHarness } from "../mocks/module/LicenseRegistryHarness.sol";

contract LicenseRegistryTest is BaseTest {
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

    error ERC721NonexistentToken(uint256 tokenId);

    MockERC721 internal gatedNftFoo = new MockERC721{ salt: bytes32(uint256(1)) }("GatedNftFoo");
    MockERC721 internal gatedNftBar = new MockERC721{ salt: bytes32(uint256(2)) }("GatedNftBar");

    mapping(uint256 => address) internal ipAcct;
    mapping(uint256 => address) internal ipOwner;
    mapping(uint256 => uint256) internal tokenIds;

    address public licenseHolder = address(0x101);

    function setUp() public override {
        super.setUp();

        ipOwner[1] = u.alice;
        ipOwner[2] = u.bob;
        ipOwner[3] = u.carl;
        ipOwner[5] = u.dan;

        // Create IPAccounts
        tokenIds[1] = mockNFT.mint(ipOwner[1]);
        tokenIds[2] = mockNFT.mint(ipOwner[2]);
        tokenIds[3] = mockNFT.mint(ipOwner[3]);
        tokenIds[5] = mockNFT.mint(ipOwner[5]);

        ipAcct[1] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[1]);
        ipAcct[2] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[2]);
        ipAcct[3] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[3]);
        ipAcct[5] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[5]);

        vm.label(ipAcct[1], "IPAccount1");
        vm.label(ipAcct[2], "IPAccount2");
        vm.label(ipAcct[3], "IPAccount3");
        vm.label(ipAcct[5], "IPAccount5");
    }

    function test_LicenseRegistry_setDefaultLicenseTerms() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.expectEmit();
        emit ILicenseRegistry.DefaultLicenseTermsSet(address(pilTemplate), socialRemixTermsId);
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) = licenseRegistry.getDefaultLicenseTerms();
        assertEq(defaultLicenseTemplate, address(pilTemplate));
        assertEq(defaultLicenseTermsId, socialRemixTermsId);
    }

    function test_LicenseRegistry_setDefaultLicenseTerms_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseRegistry__LicenseTermsNotExists.selector, address(pilTemplate), 999)
        );
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), 999);
        vm.expectRevert(Errors.LicenseRegistry__ZeroLicenseTemplate.selector);
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(0), 999);
    }

    // test registerLicenseTemplate
    function test_LicenseRegistry_registerLicenseTemplate() public {
        MockLicenseTemplate pilTemplate2 = new MockLicenseTemplate();
        vm.prank(admin);
        licenseRegistry.registerLicenseTemplate(address(pilTemplate2));
        assertTrue(licenseRegistry.isRegisteredLicenseTemplate(address(pilTemplate2)));
    }

    function test_LicenseRegistry_registerLicenseTemplate_revert_NotImplementedInterface() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__NotLicenseTemplate.selector, address(0x123)));
        vm.prank(admin);
        licenseRegistry.registerLicenseTemplate(address(0x123));
    }

    function test_LicenseRegistry_setLicensingConfigForLicense() public {
        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        Licensing.LicensingConfig memory mintingLicenseConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(0),
            hookData: ""
        });

        vm.prank(address(licensingModule));
        licenseRegistry.setLicensingConfigForLicense(
            ipAcct[1],
            address(pilTemplate),
            defaultTermsId,
            mintingLicenseConfig
        );
        Licensing.LicensingConfig memory returnedLicensingConfig = licenseRegistry.getLicensingConfig(
            ipAcct[1],
            address(pilTemplate),
            defaultTermsId
        );
        assertEq(returnedLicensingConfig.mintingFee, 100);
        assertEq(returnedLicensingConfig.licensingHook, address(0));
        assertEq(returnedLicensingConfig.hookData, "");
    }

    function test_LicenseRegistry_setLicensingConfigForLicense_revert_UnregisteredTemplate() public {
        MockLicenseTemplate pilTemplate2 = new MockLicenseTemplate();
        uint256 termsId = pilTemplate2.registerLicenseTerms();
        Licensing.LicensingConfig memory mintingLicenseConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(0),
            hookData: ""
        });

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseRegistry__UnregisteredLicenseTemplate.selector, address(pilTemplate2))
        );
        vm.prank(address(licensingModule));
        licenseRegistry.setLicensingConfigForLicense(ipAcct[1], address(pilTemplate2), termsId, mintingLicenseConfig);
    }

    function test_LicenseRegistry_setLicensingConfigForIp() public {
        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        Licensing.LicensingConfig memory mintingLicenseConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 100,
            licensingHook: address(0),
            hookData: ""
        });

        vm.prank(address(licensingModule));
        licenseRegistry.setLicensingConfigForIp(ipAcct[1], mintingLicenseConfig);

        Licensing.LicensingConfig memory returnedLicensingConfig = licenseRegistry.getLicensingConfig(
            ipAcct[1],
            address(pilTemplate),
            defaultTermsId
        );
        assertEq(returnedLicensingConfig.mintingFee, 100);
        assertEq(returnedLicensingConfig.licensingHook, address(0));
        assertEq(returnedLicensingConfig.hookData, "");
    }

    // test attachLicenseTermsToIp
    function test_LicenseRegistry_attachLicenseTermsToIp_revert_CannotAttachToDerivativeIP() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.prank(ipOwner[2]);
        licensingModule.registerDerivative(ipAcct[2], parentIpIds, licenseTermsIds, address(pilTemplate), "");

        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        vm.prank(address(licensingModule));
        licenseRegistry.attachLicenseTermsToIp(ipAcct[2], address(pilTemplate), defaultTermsId);
    }

    // test getAttachedLicenseTerms
    function test_LicenseRegistry_getAttachedLicenseTerms_revert_OutOfIndex() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());

        vm.prank(ipOwner[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IndexOutOfBounds.selector, ipAcct[1], 1, 1));
        licenseRegistry.getAttachedLicenseTerms(ipAcct[1], 1);
    }

    // test getDerivativeIp revert IndexOutOfBounds(
    function test_LicenseRegistry_getDerivativeIp_revert_IndexOutOfBounds() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.prank(ipOwner[2]);
        licensingModule.registerDerivative(ipAcct[2], parentIpIds, licenseTermsIds, address(pilTemplate), "");

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IndexOutOfBounds.selector, ipAcct[1], 1, 1));
        licenseRegistry.getDerivativeIp(ipAcct[1], 1);
    }

    function test_LicenseRegistry_getParentIp_revert_IndexOutOfBounds() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.prank(ipOwner[2]);
        licensingModule.registerDerivative(ipAcct[2], parentIpIds, licenseTermsIds, address(pilTemplate), "");

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IndexOutOfBounds.selector, ipAcct[2], 1, 1));
        licenseRegistry.getParentIp(ipAcct[2], 1);
    }

    function test_LicenseRegistry_registerDerivativeIp() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);

        vm.prank(ipOwner[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[2],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[2];
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: false
        });
        // test registerDerivativeIp using licenseToken
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[5],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: true
        });
    }

    function test_LicenseRegistry_registerDerivativeIp_unattachedLicenseTerm_usingLicenseToken() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);
        vm.prank(ipOwner[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[2],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), socialRemixTermsId);

        uint256 commercialRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
        );

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[2];
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = commercialRemixTermsId;
        licenseTermsIds[1] = commercialRemixTermsId;
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: true
        });
    }

    function test_LicenseRegistry_registerDerivativeIp_parentNoLicenseTemplate_usingLicenseToken() public {
        uint256 commercialRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
        );

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[2];
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = commercialRemixTermsId;
        licenseTermsIds[1] = commercialRemixTermsId;
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: true
        });
    }

    function test_LicenseRegistry_registerDerivativeIp_unmatchLicenseTemplate_usingLicenseToken() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);
        vm.prank(ipOwner[2]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[2],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), socialRemixTermsId);

        MockLicenseTemplate pilTemplate2 = new MockLicenseTemplate();
        vm.prank(admin);
        licenseRegistry.registerLicenseTemplate(address(pilTemplate2));
        uint256 mockTermsId = pilTemplate2.registerLicenseTerms();

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[2];
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = mockTermsId;
        licenseTermsIds[1] = mockTermsId;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__ParentIpUnmatchedLicenseTemplate.selector,
                ipAcct[1],
                address(pilTemplate2)
            )
        );

        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate2),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: true
        });
    }

    function test_LicenseRegistry_registerDerivativeIp_revert_DuplicateLicense() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__DuplicateLicense.selector,
                ipAcct[1],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[2],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: false
        });
    }

    function test_LicenseRegistry_registerDerivativeIp_revert_UnattachedLicenseTemplate() public {
        uint256 commercialRemix = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
        );

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commercialRemix;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__ParentIpHasNoLicenseTerms.selector,
                ipAcct[1],
                commercialRemix
            )
        );
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[2],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: false
        });
    }

    function test_LicenseRegistry_registerDerivativeIp_revert_UnattachedLicenseTermsId() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);
        uint256 commercialRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
        );
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commercialRemixTermsId;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__ParentIpHasNoLicenseTerms.selector,
                ipAcct[1],
                commercialRemixTermsId
            )
        );
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[2],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: false
        });
    }

    function test_LicenseRegistry_isExpiredNow() public {
        LicenseRegistryHarness lrHarness = _useLicenseRegistryHarness();
        vm.startPrank(address(licensingModule));

        lrHarness.setExpirationTime(ipAcct[1], block.timestamp + 100);
        lrHarness.setExpirationTime(ipAcct[2], block.timestamp + 200);
        vm.warp(block.timestamp + 101);
        assertTrue(lrHarness.isExpiredNow(ipAcct[1]));
        assertFalse(lrHarness.isExpiredNow(ipAcct[2]));
        assertFalse(lrHarness.isExpiredNow(ipAcct[3]));
        vm.warp(block.timestamp + 201);
        assertTrue(lrHarness.isExpiredNow(ipAcct[1]));
        assertTrue(lrHarness.isExpiredNow(ipAcct[2]));
        assertFalse(lrHarness.isExpiredNow(ipAcct[3]));
        vm.stopPrank();
    }

    function test_LicenseRegistry_revert_verifyMintLicenseToken_parentIpExpired() public {
        LicenseRegistryHarness lrHarness = _useLicenseRegistryHarness();
        vm.startPrank(address(licensingModule));
        lrHarness.setExpirationTime(ipAcct[1], block.timestamp + 100);

        vm.warp(block.timestamp + 101);
        assertTrue(lrHarness.isExpiredNow(ipAcct[1]));

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__ParentIpExpired.selector, ipAcct[1]));
        lrHarness.verifyMintLicenseToken({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: 1, // dones't need to exist for this test case
            isMintedByIpOwner: false
        });
    }

    function test_LicenseRegistry_registerDerivativeIp_parentIpExpireFirst() public {
        LicenseRegistryHarness lrHarness = _useLicenseRegistryHarness();
        vm.prank(address(licensingModule));
        lrHarness.setExpirationTime(ipAcct[1], block.timestamp + 100);
        PILTerms memory terms1 = PILFlavors.nonCommercialSocialRemixing();
        terms1.expiration = 200;
        uint256 termsId1 = pilTemplate.registerLicenseTerms(terms1);
        vm.prank(ipOwner[1]);
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), termsId1);

        PILTerms memory terms2 = PILFlavors.nonCommercialSocialRemixing();
        terms2.expiration = 400;
        uint256 termsId2 = pilTemplate.registerLicenseTerms(terms2);
        vm.prank(ipOwner[2]);
        licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), termsId2);

        address[] memory parentIpIds = new address[](2);
        uint256[] memory licenseTermsIds = new uint256[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[2];
        licenseTermsIds[0] = termsId1;
        licenseTermsIds[1] = termsId2;
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: false
        });

        assertEq(licenseRegistry.getExpireTime(ipAcct[1]), block.timestamp + 100, "ipAcct[1] expire time is incorrect");
        assertEq(licenseRegistry.getExpireTime(ipAcct[2]), 0, "ipAcct[2] expire time is incorrect");
        assertEq(licenseRegistry.getExpireTime(ipAcct[3]), block.timestamp + 100, "ipAcct[3] expire time is incorrect");
        assertEq(licenseRegistry.getParentIp(ipAcct[3], 0), ipAcct[1]);
        assertEq(licenseRegistry.getParentIp(ipAcct[3], 1), ipAcct[2]);
        (address attachedTemplate1, uint256 attachedTermsId1) = licenseRegistry.getAttachedLicenseTerms(ipAcct[3], 0);
        assertEq(attachedTemplate1, address(pilTemplate));
        assertEq(attachedTermsId1, termsId1);
        (address attachedTemplate2, uint256 attachedTermsId2) = licenseRegistry.getAttachedLicenseTerms(ipAcct[3], 1);
        assertEq(attachedTemplate2, address(pilTemplate));
        assertEq(attachedTermsId2, termsId2);
    }

    function test_LicenseRegistry_registerDerivativeIp_termsExpireFirst() public {
        LicenseRegistryHarness lrHarness = _useLicenseRegistryHarness();
        vm.prank(address(licensingModule));
        lrHarness.setExpirationTime(ipAcct[1], block.timestamp + 500);
        PILTerms memory terms1 = PILFlavors.nonCommercialSocialRemixing();
        terms1.expiration = 0;
        uint256 termsId1 = pilTemplate.registerLicenseTerms(terms1);
        vm.prank(ipOwner[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                termsId1
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), termsId1);

        PILTerms memory terms2 = PILFlavors.nonCommercialSocialRemixing();
        terms2.expiration = 400;
        uint256 termsId2 = pilTemplate.registerLicenseTerms(terms2);

        assertNotEq(termsId1, termsId2);
        vm.prank(ipOwner[2]);
        licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), termsId2);

        address[] memory parentIpIds = new address[](2);
        uint256[] memory licenseTermsIds = new uint256[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[2];
        licenseTermsIds[0] = termsId1;
        licenseTermsIds[1] = termsId2;
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTemplate: address(pilTemplate),
            licenseTermsIds: licenseTermsIds,
            isUsingLicenseToken: false
        });
        assertEq(licenseRegistry.getExpireTime(ipAcct[1]), block.timestamp + 500, "ipAcct[1] expire time is incorrect");
        assertEq(licenseRegistry.getExpireTime(ipAcct[2]), 0, "ipAcct[2] expire time is incorrect");
        assertEq(licenseRegistry.getExpireTime(ipAcct[3]), block.timestamp + 400, "ipAcct[3] expire time is incorrect");
        assertEq(licenseRegistry.getParentIp(ipAcct[3], 0), ipAcct[1]);
        assertEq(licenseRegistry.getParentIp(ipAcct[3], 1), ipAcct[2]);
        (address attachedTemplate1, uint256 attachedTermsId1) = licenseRegistry.getAttachedLicenseTerms(ipAcct[3], 0);
        assertEq(attachedTemplate1, address(pilTemplate));
        assertEq(attachedTermsId1, termsId1);
        (address attachedTemplate2, uint256 attachedTermsId2) = licenseRegistry.getAttachedLicenseTerms(ipAcct[3], 1);
        assertEq(attachedTemplate2, address(pilTemplate));
        assertEq(attachedTermsId2, termsId2);
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _useLicenseRegistryHarness() internal returns (LicenseRegistryHarness) {
        vm.prank(u.admin);
        // solhint-disable-next-line unused-vars
        (bytes32 operationId, uint32 nonce) = protocolAccessManager.schedule(
            address(licenseRegistry),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (lrHarnessImpl, "")),
            0 // earliest time possible, upgraderExecDelay
        );
        vm.warp(upgraderExecDelay + 1);

        vm.prank(u.admin);
        licenseRegistry.upgradeToAndCall(address(lrHarnessImpl), "");
        return LicenseRegistryHarness(address(licenseRegistry));
    }
}
