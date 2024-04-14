// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccount } from "../../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../contracts/lib/PILFlavors.sol";
import { MockLicenseTemplate } from "../mocks/module/MockLicenseTemplate.sol";
import { IPAccountStorageOps } from "../../../contracts/lib/IPAccountStorageOps.sol";
import { Licensing } from "../../../contracts/lib/Licensing.sol";

// test
import { MockERC721 } from "../mocks/token/MockERC721.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract LicenseRegistryTest is BaseTest {
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

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

    function test_LicenseRegistry_setDisputeModule() public {
        vm.prank(admin);
        licenseRegistry.setDisputeModule(address(123));
        assertEq(address(licenseRegistry.disputeModule()), address(123));
    }

    function test_LicenseRegistry_setLicensingModule() public {
        vm.prank(admin);
        licenseRegistry.setLicensingModule(address(123));
        assertEq(address(licenseRegistry.licensingModule()), address(123));
    }

    function test_LicenseRegistry_setDisputeModule_revert_ZeroAddress() public {
        vm.expectRevert(Errors.LicenseRegistry__ZeroDisputeModule.selector);
        vm.prank(admin);
        licenseRegistry.setDisputeModule(address(0));
    }

    function test_LicenseRegistry_setLicensingModule_revert_ZeroAddress() public {
        vm.expectRevert(Errors.LicenseRegistry__ZeroLicensingModule.selector);
        vm.prank(admin);
        licenseRegistry.setLicensingModule(address(0));
    }

    function test_LicenseRegistry_setDefaultLicenseTerms() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);
        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) = licenseRegistry.getDefaultLicenseTerms();
        assertEq(defaultLicenseTemplate, address(pilTemplate));
        assertEq(defaultLicenseTermsId, socialRemixTermsId);
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

    function test_LicenseRegistry_setExpireTime() public {
        vm.prank(address(licensingModule));
        licenseRegistry.setExpireTime(ipId1, block.timestamp + 100);
        assertEq(licenseRegistry.getExpireTime(ipId1), block.timestamp + 100);
        assertEq(
            IIPAccount(payable(ipId1)).getUint256(address(licenseRegistry), licenseRegistry.EXPIRATION_TIME()),
            block.timestamp + 100
        );
    }

    function test_LicenseRegistry_setMintingLicenseConfigForLicense() public {
        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        Licensing.MintingLicenseConfig memory mintingLicenseConfig = Licensing.MintingLicenseConfig({
            isSet: true,
            mintingFee: 100,
            mintingFeeModule: address(0),
            receiverCheckModule: address(0),
            receiverCheckData: ""
        });

        vm.prank(address(licensingModule));
        licenseRegistry.setMintingLicenseConfigForLicense(
            ipId1,
            address(pilTemplate),
            defaultTermsId,
            mintingLicenseConfig
        );
        Licensing.MintingLicenseConfig memory returnedMintingLicenseConfig = licenseRegistry.getMintingLicenseConfig(
            ipId1,
            address(pilTemplate),
            defaultTermsId
        );
        assertEq(returnedMintingLicenseConfig.mintingFee, 100);
        assertEq(returnedMintingLicenseConfig.mintingFeeModule, address(0));
        assertEq(returnedMintingLicenseConfig.receiverCheckModule, address(0));
        assertEq(returnedMintingLicenseConfig.receiverCheckData, "");
    }

    function test_LicenseRegistry_setMintingLicenseConfigForLicense_revert_UnregisteredTemplate() public {
        MockLicenseTemplate pilTemplate2 = new MockLicenseTemplate();
        uint256 termsId = pilTemplate2.registerLicenseTerms();
        Licensing.MintingLicenseConfig memory mintingLicenseConfig = Licensing.MintingLicenseConfig({
            isSet: true,
            mintingFee: 100,
            mintingFeeModule: address(0),
            receiverCheckModule: address(0),
            receiverCheckData: ""
        });

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseRegistry__UnregisteredLicenseTemplate.selector, address(pilTemplate2))
        );
        vm.prank(address(licensingModule));
        licenseRegistry.setMintingLicenseConfigForLicense(ipId1, address(pilTemplate2), termsId, mintingLicenseConfig);
    }

    function test_LicenseRegistry_setMintingLicenseConfigForIp() public {
        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        Licensing.MintingLicenseConfig memory mintingLicenseConfig = Licensing.MintingLicenseConfig({
            isSet: true,
            mintingFee: 100,
            mintingFeeModule: address(0),
            receiverCheckModule: address(0),
            receiverCheckData: ""
        });

        vm.prank(address(licensingModule));
        licenseRegistry.setMintingLicenseConfigForIp(ipId1, mintingLicenseConfig);

        Licensing.MintingLicenseConfig memory returnedMintingLicenseConfig = licenseRegistry.getMintingLicenseConfig(
            ipId1,
            address(pilTemplate),
            defaultTermsId
        );
        assertEq(returnedMintingLicenseConfig.mintingFee, 100);
        assertEq(returnedMintingLicenseConfig.mintingFeeModule, address(0));
        assertEq(returnedMintingLicenseConfig.receiverCheckModule, address(0));
        assertEq(returnedMintingLicenseConfig.receiverCheckData, "");
    }

    // test attachLicenseTermsToIp
    function test_LicenseRegistry_attachLicenseTermsToIp_revert_CannotAttachToDerivativeIP() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");

        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddLicenseTerms.selector);
        vm.prank(address(licensingModule));
        licenseRegistry.attachLicenseTermsToIp(ipId2, address(pilTemplate), defaultTermsId);
    }

    function test_LicenseRegistry_registerDerivativeIp_revert_parentsArrayEmpty() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](0);
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.expectRevert(Errors.LicenseRegistry__NoParentIp.selector);
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp(ipId2, parentIpIds, address(pilTemplate), licenseTermsIds);
    }

    // test getAttachedLicenseTerms
    function test_LicenseRegistry_getAttachedLicenseTerms_revert_OutOfIndex() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), socialRemixTermsId);
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IndexOutOfBounds.selector, ipId1, 1, 1));
        licenseRegistry.getAttachedLicenseTerms(ipId1, 1);
    }

    // test getDerivativeIp revert IndexOutOfBounds(
    function test_LicenseRegistry_getDerivativeIp_revert_IndexOutOfBounds() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IndexOutOfBounds.selector, ipId1, 1, 1));
        licenseRegistry.getDerivativeIp(ipId1, 1);
    }

    function test_LicenseRegistry_getParentIp_revert_IndexOutOfBounds() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IndexOutOfBounds.selector, ipId2, 1, 1));
        licenseRegistry.getParentIp(ipId2, 1);
    }

    function test_LicenseRegistry_registerDerivativeIp() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), socialRemixTermsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId2;
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp(ipId3, parentIpIds, address(pilTemplate), licenseTermsIds);
    }

    function test_LicenseRegistry_registerDerivativeIp_revert_DuplicateLicense() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__DuplicateLicense.selector,
                ipId1,
                address(pilTemplate),
                socialRemixTermsId
            )
        );
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp(ipId2, parentIpIds, address(pilTemplate), licenseTermsIds);
    }

    function test_LicenseRegistry_isExpiredNow() public {
        vm.startPrank(address(licensingModule));
        licenseRegistry.setExpireTime(ipId1, block.timestamp + 100);
        licenseRegistry.setExpireTime(ipId2, block.timestamp + 200);
        vm.warp(block.timestamp + 101);
        assertTrue(licenseRegistry.isExpiredNow(ipId1));
        assertFalse(licenseRegistry.isExpiredNow(ipId2));
        assertFalse(licenseRegistry.isExpiredNow(ipId3));
        vm.warp(block.timestamp + 201);
        assertTrue(licenseRegistry.isExpiredNow(ipId1));
        assertTrue(licenseRegistry.isExpiredNow(ipId2));
        assertFalse(licenseRegistry.isExpiredNow(ipId3));
        vm.stopPrank();
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
