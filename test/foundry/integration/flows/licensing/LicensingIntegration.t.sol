// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Test } from "forge-std/Test.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

// contracts
import { AccessController } from "../../../../../contracts/access/AccessController.sol";
import { IPAccountImpl } from "../../../../../contracts/IPAccountImpl.sol";
import { IPAssetRegistry } from "../../../../../contracts/registries/IPAssetRegistry.sol";
import { ModuleRegistry } from "../../../../../contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "../../../../../contracts/registries/LicenseRegistry.sol";
import { RoyaltyModule } from "../../../../../contracts/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "../../../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { DisputeModule } from "../../../../../contracts/modules/dispute/DisputeModule.sol";
import { LicensingModule } from "../../../../../contracts/modules/licensing/LicensingModule.sol";
import { ArbitrationPolicySP } from "../../../../../contracts/modules/dispute/policies/ArbitrationPolicySP.sol";
import { IpRoyaltyVault } from "../../../../../contracts/modules/royalty/policies/IpRoyaltyVault.sol";
import { LicenseToken } from "../../../../../contracts/LicenseToken.sol";
import { DISPUTE_MODULE_KEY, LICENSING_MODULE_KEY, ROYALTY_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { PILicenseTemplate } from "../../../../../contracts/modules/licensing/PILicenseTemplate.sol";
import { PILFlavors } from "../../../../../contracts/lib/PILFlavors.sol";
import { MockERC20 } from "../../../mocks/token/MockERC20.sol";
import { MockERC721 } from "../../../mocks/token/MockERC721.sol";
import { TestProxyHelper } from "../../../utils/TestProxyHelper.sol";

contract e2e is Test {
    MockERC20 erc20;
    MockERC721 mockNft;
    uint256 internal constant ARBITRATION_PRICE = 1000;

    address admin;
    address alice;
    address bob;
    address charlie;
    address dave;
    address eve;

    AccessManager protocolAccessManager;
    AccessController accessController;
    ModuleRegistry moduleRegistry;
    ERC6551Registry erc6551Registry;
    IPAccountImpl ipAccountImpl;
    IPAssetRegistry ipAssetRegistry;
    LicenseRegistry licenseRegistry;
    LicenseToken licenseToken;
    RoyaltyModule royaltyModule;
    DisputeModule disputeModule;
    LicensingModule licensingModule;
    PILicenseTemplate piLicenseTemplate;
    RoyaltyPolicyLAP royaltyPolicyLAP;

    address ipId1;
    address ipId2;
    address ipId3;
    address ipId6;
    address ipId7;

    error ERC721NonexistentToken(uint256 tokenId);

    function setUp() public {
        admin = vm.addr(1);
        alice = vm.addr(2);
        bob = vm.addr(3);
        charlie = vm.addr(4);
        dave = vm.addr(5);
        eve = vm.addr(6);

        erc20 = new MockERC20();
        mockNft = new MockERC721("ape");
        protocolAccessManager = new AccessManager(admin);

        // Deploy contracts
        address impl = address(new AccessController());
        accessController = AccessController(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(AccessController.initialize, address(protocolAccessManager))
            )
        );

        impl = address(new ModuleRegistry());
        moduleRegistry = ModuleRegistry(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(AccessController.initialize, address(protocolAccessManager))
            )
        );

        erc6551Registry = new ERC6551Registry();
        ipAccountImpl = new IPAccountImpl(address(accessController));
        impl = address(new IPAssetRegistry(address(erc6551Registry), address(ipAccountImpl)));
        ipAssetRegistry = IPAssetRegistry(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(IPAssetRegistry.initialize, address(protocolAccessManager))
            )
        );

        impl = address(new LicenseRegistry());
        licenseRegistry = LicenseRegistry(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(LicenseRegistry.initialize, (address(protocolAccessManager)))
            )
        );

        impl = address(new LicenseToken());
        licenseToken = LicenseToken(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(LicenseToken.initialize, (address(protocolAccessManager), "image_url"))
            )
        );

        impl = address(
            new DisputeModule(address(accessController), address(ipAssetRegistry), address(licenseRegistry))
        );

        disputeModule = DisputeModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(DisputeModule.initialize, (address(protocolAccessManager)))
            )
        );

        impl = address(new RoyaltyModule(address(disputeModule), address(licenseRegistry)));
        royaltyModule = RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyModule.initialize, (address(protocolAccessManager)))
            )
        );
        vm.label(address(royaltyModule), "RoyaltyModule");

        impl = address(
            new LicensingModule(
                address(accessController),
                address(ipAssetRegistry),
                address(royaltyModule),
                address(licenseRegistry),
                address(disputeModule),
                address(licenseToken)
            )
        );

        licensingModule = LicensingModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(LicensingModule.initialize, (address(protocolAccessManager)))
            )
        );

        erc20 = new MockERC20();
        mockNft = new MockERC721("ape");

        impl = address(new ArbitrationPolicySP(address(disputeModule), address(erc20), ARBITRATION_PRICE));
        ArbitrationPolicySP arbitrationPolicySP = ArbitrationPolicySP(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(ArbitrationPolicySP.initialize, (address(protocolAccessManager)))
            )
        );

        impl = address(new RoyaltyPolicyLAP(address(royaltyModule), address(licensingModule)));
        royaltyPolicyLAP = RoyaltyPolicyLAP(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyPolicyLAP.initialize, (address(protocolAccessManager)))
            )
        );

        impl = address(
            new PILicenseTemplate(
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(royaltyModule)
            )
        );
        piLicenseTemplate = PILicenseTemplate(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(
                    PILicenseTemplate.initialize,
                    (address(protocolAccessManager), "PIL", "PIL-metadata-url")
                )
            )
        );

        // Configure protocol
        vm.startPrank(admin);

        address ipRoyaltyVaultImplementation = address(
            new IpRoyaltyVault(address(royaltyPolicyLAP), address(disputeModule))
        );
        address ipRoyaltyVaultBeacon = address(
            new UpgradeableBeacon(ipRoyaltyVaultImplementation, address(protocolAccessManager))
        );
        royaltyPolicyLAP.setIpRoyaltyVaultBeacon(ipRoyaltyVaultBeacon);

        royaltyPolicyLAP.setSnapshotInterval(7 days);

        accessController.setAddresses(address(ipAssetRegistry), address(moduleRegistry));

        moduleRegistry.registerModule(DISPUTE_MODULE_KEY, address(disputeModule));
        moduleRegistry.registerModule(LICENSING_MODULE_KEY, address(licensingModule));
        moduleRegistry.registerModule(ROYALTY_MODULE_KEY, address(royaltyModule));

        royaltyModule.setLicensingModule(address(licensingModule));
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);

        disputeModule.whitelistDisputeTag("PLAGIARISM", true);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), admin, true);
        disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP));

        licenseRegistry.setDisputeModule(address(disputeModule));
        licenseRegistry.setLicensingModule(address(licensingModule));
        licenseRegistry.registerLicenseTemplate(address(piLicenseTemplate));

        licenseToken.setDisputeModule(address(disputeModule));
        licenseToken.setLicensingModule(address(licensingModule));

        vm.stopPrank();
    }

    function test_e2e() public {
        uint256 tokenId1 = mockNft.mint(alice);
        uint256 tokenId2 = mockNft.mint(bob);
        uint256 tokenId3 = mockNft.mint(charlie);
        uint256 tokenId6 = mockNft.mint(dave);
        uint256 tokenId7 = mockNft.mint(eve);

        ipId1 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId1);
        ipId2 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId2);
        ipId3 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId3);
        ipId6 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId6);
        ipId7 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId7);

        // register license terms
        uint256 lcId1 = piLicenseTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        assertEq(lcId1, 1);

        uint256 lcId2 = piLicenseTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
        );
        assertEq(lcId2, 2);
        assertEq(
            piLicenseTemplate.getLicenseTermsId(
                PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
            ),
            2
        );
        assertTrue(piLicenseTemplate.exists(2));

        assertTrue(piLicenseTemplate.exists(lcId2));

        // attach licenses
        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(ipId1, address(piLicenseTemplate), 1);

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(piLicenseTemplate), 1), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);

        (address attachedTemplate, uint256 attachedId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertEq(attachedTemplate, address(piLicenseTemplate));
        assertEq(attachedId, 1);

        licensingModule.attachLicenseTerms(ipId1, address(piLicenseTemplate), 2);

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(piLicenseTemplate), 2), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 2);

        (attachedTemplate, attachedId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 1);
        assertEq(attachedTemplate, address(piLicenseTemplate));
        assertEq(attachedId, 2);
        vm.stopPrank();

        // register derivative directly
        vm.startPrank(bob);
        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = 1;

        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(piLicenseTemplate), "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(piLicenseTemplate), 1), true);
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
        vm.stopPrank();

        // mint license token
        vm.startPrank(charlie);
        uint256 lcTokenId = licensingModule.mintLicenseTokens(
            ipId1,
            address(piLicenseTemplate),
            1,
            1,
            address(charlie),
            ""
        );
        assertEq(licenseToken.ownerOf(lcTokenId), charlie);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), 1);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(piLicenseTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.getExpirationTime(lcTokenId), 0);
        assertEq(licenseToken.totalMintedTokens(), 1);

        // register derivative with license tokens
        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId3, address(piLicenseTemplate), 1), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId3), 1);
        assertEq(licenseRegistry.isDerivativeIp(ipId3), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId3), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 2);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId2), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId2);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 1), ipId3);
        assertEq(licenseRegistry.getParentIp(ipId3, 0), ipId1);
        assertEq(licenseRegistry.getParentIpCount(ipId3), 1);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        assertEq(licenseToken.ownerOf(lcTokenId), address(0));
        assertEq(licenseToken.totalMintedTokens(), 1);
        vm.stopPrank();

        // mint license token with payments
        vm.startPrank(dave);
        erc20.mint(dave, 1000);
        erc20.approve(address(royaltyPolicyLAP), 100);

        lcTokenId = licensingModule.mintLicenseTokens(ipId1, address(piLicenseTemplate), 2, 1, address(dave), "");

        assertEq(licenseToken.ownerOf(lcTokenId), dave);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), 2);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(piLicenseTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipId1);
        assertEq(licenseToken.getExpirationTime(lcTokenId), 0);
        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(erc20.balanceOf(dave), 900);

        // register derivative with license tokens
        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        licensingModule.registerDerivativeWithLicenseTokens(ipId6, licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId6, address(piLicenseTemplate), 2), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId6), 1);
        assertEq(licenseRegistry.isDerivativeIp(ipId6), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId6), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 3);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId6), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 0), ipId2);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 1), ipId3);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 2), ipId6);
        assertEq(licenseRegistry.getParentIp(ipId6, 0), ipId1);
        assertEq(licenseRegistry.getParentIpCount(ipId6), 1);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        assertEq(licenseToken.ownerOf(lcTokenId), address(0));
        assertEq(licenseToken.totalMintedTokens(), 2);
        vm.stopPrank();

        // register derivative directly with payments
        vm.startPrank(eve);
        erc20.mint(eve, 1000);
        erc20.approve(address(royaltyPolicyLAP), 100);
        parentIpIds = new address[](1);
        licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = 2;

        licensingModule.registerDerivative(ipId7, parentIpIds, licenseTermsIds, address(piLicenseTemplate), "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipId7, address(piLicenseTemplate), 2), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId7), 1);
        assertEq(licenseRegistry.isDerivativeIp(ipId7), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipId7), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipId1), true);
        assertEq(licenseRegistry.isDerivativeIp(ipId1), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 4);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId7), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipId1, 3), ipId7);
        assertEq(licenseRegistry.getParentIp(ipId7, 0), ipId1);
        assertEq(licenseRegistry.getParentIpCount(ipId7), 1);
        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(erc20.balanceOf(eve), 900);
        vm.stopPrank();
    }
}
