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
        licenseRegistry.setExpireTime(ipAcct[1], block.timestamp + 100);
        assertEq(licenseRegistry.getExpireTime(ipAcct[1]), block.timestamp + 100);
        assertEq(
            IIPAccount(payable(ipAcct[1])).getUint256(address(licenseRegistry), licenseRegistry.EXPIRATION_TIME()),
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
            ipAcct[1],
            address(pilTemplate),
            defaultTermsId,
            mintingLicenseConfig
        );
        Licensing.MintingLicenseConfig memory returnedMintingLicenseConfig = licenseRegistry.getMintingLicenseConfig(
            ipAcct[1],
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
        licenseRegistry.setMintingLicenseConfigForLicense(
            ipAcct[1],
            address(pilTemplate2),
            termsId,
            mintingLicenseConfig
        );
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
        licenseRegistry.setMintingLicenseConfigForIp(ipAcct[1], mintingLicenseConfig);

        Licensing.MintingLicenseConfig memory returnedMintingLicenseConfig = licenseRegistry.getMintingLicenseConfig(
            ipAcct[1],
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

    function test_LicenseRegistry_registerDerivativeIp_revert_parentsArrayEmpty() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](0);
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.expectRevert(Errors.LicenseRegistry__NoParentIp.selector);
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp(ipAcct[2], parentIpIds, address(pilTemplate), licenseTermsIds);
    }

    // test getAttachedLicenseTerms
    function test_LicenseRegistry_getAttachedLicenseTerms_revert_OutOfIndex() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());

        vm.prank(ipOwner[1]);
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
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);
        vm.prank(ipOwner[2]);
        licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), socialRemixTermsId);

        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[2];
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        vm.prank(address(licensingModule));
        licenseRegistry.registerDerivativeIp(ipAcct[3], parentIpIds, address(pilTemplate), licenseTermsIds);
    }

    function test_LicenseRegistry_registerDerivativeIp_revert_DuplicateLicense() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        vm.prank(ipOwner[1]);
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
        licenseRegistry.registerDerivativeIp(ipAcct[2], parentIpIds, address(pilTemplate), licenseTermsIds);
    }

    function test_LicenseRegistry_isExpiredNow() public {
        vm.startPrank(address(licensingModule));
        licenseRegistry.setExpireTime(ipAcct[1], block.timestamp + 100);
        licenseRegistry.setExpireTime(ipAcct[2], block.timestamp + 200);
        vm.warp(block.timestamp + 101);
        assertTrue(licenseRegistry.isExpiredNow(ipAcct[1]));
        assertFalse(licenseRegistry.isExpiredNow(ipAcct[2]));
        assertFalse(licenseRegistry.isExpiredNow(ipAcct[3]));
        vm.warp(block.timestamp + 201);
        assertTrue(licenseRegistry.isExpiredNow(ipAcct[1]));
        assertTrue(licenseRegistry.isExpiredNow(ipAcct[2]));
        assertFalse(licenseRegistry.isExpiredNow(ipAcct[3]));
        vm.stopPrank();
    }

    function test_LicenseRegistry_revert_verifyMintLicenseToken_parentIpExpired() public {
        vm.startPrank(address(licensingModule));
        licenseRegistry.setExpireTime(ipAcct[1], block.timestamp + 100);

        vm.warp(block.timestamp + 101);
        assertTrue(licenseRegistry.isExpiredNow(ipAcct[1]));

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__ParentIpExpired.selector, ipAcct[1]));
        licenseRegistry.verifyMintLicenseToken({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: 1, // dones't need to exist for this test case
            isMintedByIpOwner: false
        });
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
