// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { DeployHelper_V1_1_0 } from "./DeployHelper_V1_1_0.sol";
// solhint-disable-next-line max-line-length
import { ImplDeployerV1_1_0, UpgradedImplHelper } from "../../../script/foundry/upgrades/testnet/v1-1-0_impl-deployer.sol";
import { Users, UsersLib } from "../utils/Users.t.sol";
import { MockERC20 } from "../mocks/token/MockERC20.sol";
import { MockERC721 } from "../mocks/token/MockERC721.sol";
// solhint-disable-next-line max-line-length
import { LicensingModule_V1_0_0, Licensing_V1_0_0, PILTerms_V1_0_0, PILFlavors, IRoyaltyPolicyLAP } from "contracts/old/v1.0.0.sol";

import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { ShortStringOps } from "contracts/lib/ShortStringOps.sol";
import { IPAccountStorageOps } from "contracts/lib/IPAccountStorageOps.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { LicenseToken } from "contracts/LicenseToken.sol";
import { PILicenseTemplate } from "contracts/modules/licensing/PILicenseTemplate.sol";
import { PILTerms } from "contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Create3Deployer } from "@create3-deployer/contracts/Create3Deployer.sol";

// solhint-disable no-console
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";

contract Upgradesv1_1_0Test is DeployHelper_V1_1_0, Test {
    /// @dev Users struct to abstract away user management when testing
    Users internal u;

    address internal ipaOwner;
    address internal derivativeOwner;
    address internal signer;
    address internal admin;
    address internal rel;

    ERC6551Registry internal ERC6551_REGISTRY = new ERC6551Registry();
    Create3Deployer internal CREATE3_DEPLOYER = new Create3Deployer();
    uint256 internal CREATE3_DEFAULT_SEED = 0;

    MockERC20 internal erc20 = new MockERC20();
    MockERC20 internal erc20bb = new MockERC20();

    /// @dev Aliases for mock assets.
    MockERC20 internal mockToken; // alias for erc20
    MockERC20 internal USDC; // alias for mockToken/erc20
    MockERC20 internal LINK; // alias for erc20bb
    MockERC721 internal mockNFT;

    using IPAccountStorageOps for IIPAccount;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 MockToken (6 decimals)
    uint256 internal constant MAX_ROYALTY_APPROVAL = 10000 ether;

    uint32 execDelay = 600;

    string contractKey;
    address impl;

    IIPAccount ipa;
    IIPAccount derivIpa;
    PILTerms_V1_0_0 defaultTerms;
    uint256 defaultTermsId;
    PILTerms_V1_0_0 terms;
    uint256 termsId;
    bytes32[] tokenURIs;
    bytes32 tag;
    bytes32 evidence;
    string ipaName;
    string ipaUri;
    uint256 ipaRegistrationDate;
    string derivIpaName;
    string derivIpaUri;
    uint256 derivIpaRegistrationDate;
    IRoyaltyPolicyLAP.LAPRoyaltyData ipaRoyaltyData;
    IRoyaltyPolicyLAP.LAPRoyaltyData derivIpaRoyaltyData;

    ImplDeployerV1_1_0 implDeployer;
    Licensing_V1_0_0.MintingLicenseConfig ipaLicConfig;
    Licensing_V1_0_0.MintingLicenseConfig derivIpaLicConfig;

    constructor()
        DeployHelper_V1_1_0(
            address(ERC6551_REGISTRY),
            address(CREATE3_DEPLOYER),
            address(erc20),
            ARBITRATION_PRICE,
            MAX_ROYALTY_APPROVAL
        )
    {}

    function setUp() public {
        implDeployer = new ImplDeployerV1_1_0();
    }

    function test_upgrade() public {
        u = UsersLib.createMockUsers(vm);

        admin = u.admin;
        ipaOwner = u.alice;
        signer = u.bob;
        derivativeOwner = u.carl;
        rel = u.dan;

        // Set aliases
        mockToken = erc20;
        USDC = erc20;
        LINK = erc20bb;
        mockNFT = new MockERC721("Ape");
        dealMockAssets();

        super.run(0, false, true);

        // 1) Set up state
        setState();

        // 2) Deploy new (V1.1.0) implementations

        ImplDeployerV1_1_0.ProxiesToUpgrade memory proxies = ImplDeployerV1_1_0.ProxiesToUpgrade(
            address(licenseToken),
            address(licensingModule),
            address(licenseRegistry),
            address(pilTemplate),
            address(accessController),
            address(royaltyModule),
            address(royaltyPolicyLAP),
            address(ipAssetRegistry)
        );

        ImplDeployerV1_1_0.Dependencies memory dependencies = ImplDeployerV1_1_0.Dependencies(
            address(disputeModule),
            address(moduleRegistry)
        );

        UpgradedImplHelper.UpgradeProposal[] memory proposals = implDeployer.deploy(
            0,
            address(erc6551Registry),
            proxies,
            dependencies
        );

        // 3) Upgrade
        vm.prank(u.admin);
        protocolAccessManager.grantRole(ProtocolAdmin.UPGRADER_ROLE, u.bob, execDelay);
        for (uint256 i = 0; i < proposals.length; i++) {
            upgrade(proposals[i]);
        }

        // 4) Test state
        testState();
    }

    function setState() internal {
        // Register IPAs
        mockNFT.mintId(ipaOwner, 1);
        mockNFT.mintId(derivativeOwner, 2);

        ipa = IIPAccount(payable(ipAssetRegistry.register(block.chainid, address(mockNFT), 1)));
        assertTrue(ipAssetRegistry.isRegistered(address(ipa)));
        ipaName = ipa.getString("NAME");
        ipaUri = ipa.getString("URI");
        ipaRegistrationDate = ipa.getUint256("REGISTRATION_DATE");

        derivIpa = IIPAccount(payable(ipAssetRegistry.register(block.chainid, address(mockNFT), 2)));
        assertTrue(ipAssetRegistry.isRegistered(address(derivIpa)));
        derivIpaName = derivIpa.getString("NAME");
        derivIpaUri = derivIpa.getString("URI");
        derivIpaRegistrationDate = derivIpa.getUint256("REGISTRATION_DATE");

        // Set Permissions
        vm.prank(ipaOwner);
        ipa.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipa),
                signer,
                address(licensingModule),
                LicensingModule_V1_0_0.attachLicenseTerms.selector,
                AccessPermission.ALLOW
            )
        );

        // Set Licensing terms
        defaultTerms = PILFlavors.commercialRemix(0, 10, address(royaltyPolicyLAP), address(erc20));
        terms.expiration = block.timestamp + 10000;
        defaultTermsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(admin);
        licenseRegistry.setDefaultLicenseTerms(address(pilTemplate), defaultTermsId);

        terms = PILFlavors.commercialRemix(100, 100, address(royaltyPolicyLAP), address(erc20));
        termsId = pilTemplate.registerLicenseTerms(terms);

        //// Attach terms
        vm.prank(signer);
        licensingModule.attachLicenseTerms(address(ipa), address(pilTemplate), termsId);

        //// Mint licenses
        vm.startPrank(ipaOwner);
        USDC.approve(address(royaltyPolicyLAP), 2 ether);
        licensingModule.mintLicenseTokens(address(ipa), address(pilTemplate), termsId, 2, ipaOwner, "");
        ipaLicConfig = Licensing_V1_0_0.MintingLicenseConfig({
            isSet: true,
            mintingFee: 100,
            mintingFeeModule: address(royaltyPolicyLAP),
            receiverCheckModule: address(0x123),
            receiverCheckData: bytes("hey")
        });
        vm.stopPrank();
        // TODO: how to set this?
        // vm.prank(address(licensingModule));
        // licenseRegistry.setMintingLicenseConfigForLicense(address(ipa), address(pilTemplate), termsId, ipaLicConfig);
        vm.startPrank(ipaOwner);
        licensingModule.mintLicenseTokens(address(ipa), address(pilTemplate), defaultTermsId, 1, derivativeOwner, "");
        derivIpaLicConfig = Licensing_V1_0_0.MintingLicenseConfig({
            isSet: true,
            mintingFee: 200,
            mintingFeeModule: address(0x123),
            receiverCheckModule: address(0x123),
            receiverCheckData: bytes("yo")
        });
        vm.stopPrank();
        // TODO: how to set this?
        // vm.prank(address(licensingModule));
        // licenseRegistry.setMintingLicenseConfigForLicense(
        // address(derivIpa), address(pilTemplate), defaultTermsId, derivIpaLicConfig
        // );

        // Register Derivative
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = address(ipa);
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = termsId;

        vm.startPrank(derivativeOwner);
        USDC.approve(address(royaltyPolicyLAP), 2 ether);
        licensingModule.registerDerivative(address(derivIpa), parentIpIds, licenseTermsIds, address(pilTemplate), "");
        vm.stopPrank();

        //// Royalty
        vm.startPrank(u.bob);
        USDC.approve(address(royaltyPolicyLAP), 1 ether);
        royaltyModule.payRoyaltyOnBehalf(address(ipa), address(derivIpa), address(USDC), 1 ether);
        (
            bool unlinkable,
            address vault,
            uint32 stack,
            address[] memory ancestors,
            uint32[] memory ancestorsRoyalty
        ) = royaltyPolicyLAP.getRoyaltyData(address(ipa));

        ipaRoyaltyData = IRoyaltyPolicyLAP.LAPRoyaltyData(unlinkable, vault, stack, ancestors, ancestorsRoyalty);
        vm.stopPrank();
        (unlinkable, vault, stack, ancestors, ancestorsRoyalty) = royaltyPolicyLAP.getRoyaltyData(address(derivIpa));

        derivIpaRoyaltyData = IRoyaltyPolicyLAP.LAPRoyaltyData(unlinkable, vault, stack, ancestors, ancestorsRoyalty);

        // TODO: claim tokens to check Royalty balance storage
        // vm.prank(ipaRoyaltyData.ipRoyaltyVault);
        //IIpRoyaltyVault(ipaRoyaltyData.ipRoyaltyVault).collectRoyaltyTokens(address(ipa));

        //// Disputes
        vm.startPrank(u.admin);
        tag = ShortStringOps.stringToBytes32("test");
        disputeModule.whitelistDisputeTag(tag, true);
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), rel, true);
        vm.stopPrank();
        evidence = ShortStringOps.stringToBytes32("evidence");

        vm.startPrank(u.carl);
        USDC.approve(address(arbitrationPolicySP), 1000000 ether);
        uint256 disputeId = disputeModule.raiseDispute(address(ipa), "evidence", tag, "");
        vm.stopPrank();
        vm.prank(rel);
        disputeModule.setDisputeJudgement(disputeId, true, "");
        vm.prank(u.carl);
        disputeModule.tagDerivativeIfParentInfringed(address(ipa), address(derivIpa), disputeId);

        // Pause
        vm.prank(u.admin);
        protocolPauser.pause();
    }

    function testState() internal {
        // IPAccountImpl
        assertEq(ipa.owner(), ipaOwner);
        assertEq(ipaName, ipa.getString("NAME"));
        assertEq(ipaUri, ipa.getString("URI"));
        assertEq(ipaRegistrationDate, ipa.getUint256("REGISTRATION_DATE"));

        assertEq(derivIpa.owner(), derivativeOwner);
        assertEq(derivIpaName, derivIpa.getString("NAME"));
        assertEq(derivIpaUri, derivIpa.getString("URI"));
        assertEq(derivIpaRegistrationDate, derivIpa.getUint256("REGISTRATION_DATE"));

        // Access Control
        assertEq(
            accessController.getPermission(
                address(ipa),
                signer,
                address(licensingModule),
                LicensingModule_V1_0_0.attachLicenseTerms.selector
            ),
            AccessPermission.ALLOW
        );

        // IPAssetRegistry
        assertEq(ipAssetRegistry.totalSupply(), 2);
        // NOTE: We need to fix this, upgrading IPAssetRegistry should keep the versions
        //assertEq(ipAssetRegistry.isRegistered(address(ipa)), true);
        //assertEq(ipAssetRegistry.isRegistered(address(derivIpa)), true);
        assertTrue(ipAssetRegistry.paused());

        // DisputeModule
        assertTrue(disputeModule.paused());
        assertEq(disputeModule.isIpTagged(address(ipa)), true);
        assertEq(disputeModule.isIpTagged(address(derivIpa)), true);
        assertEq(disputeModule.disputeCounter(), 2);
        assertEq(disputeModule.baseArbitrationPolicy(), address(arbitrationPolicySP));

        (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 linkToDisputeEvidence,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 parentDisputeId
        ) = disputeModule.disputes(1);
        assertEq(targetIpId, address(ipa));
        assertEq(disputeInitiator, address(u.carl));
        assertEq(arbitrationPolicy, address(arbitrationPolicySP));
        assertEq(linkToDisputeEvidence, evidence);
        assertEq(targetTag, tag);
        assertEq(currentTag, tag);
        assertEq(parentDisputeId, 0);

        (
            targetIpId,
            disputeInitiator,
            arbitrationPolicy,
            linkToDisputeEvidence,
            targetTag,
            currentTag,
            parentDisputeId
        ) = disputeModule.disputes(2);
        assertEq(targetIpId, address(derivIpa));
        assertEq(disputeInitiator, address(u.carl));
        assertEq(arbitrationPolicy, address(arbitrationPolicySP));
        assertEq(linkToDisputeEvidence, bytes32(0));
        assertEq(targetTag, tag);
        assertEq(currentTag, tag);
        assertEq(parentDisputeId, 1);

        // RoyaltyModule
        assertTrue(royaltyModule.paused());
        assertTrue(royaltyModule.isWhitelistedRoyaltyPolicy(address(royaltyPolicyLAP)));
        assertTrue(royaltyModule.isWhitelistedRoyaltyToken(address(erc20)));
        // TODO: check
        //assertEq(royaltyModule.royaltyPolicies(address(ipa)), address(royaltyPolicyLAP));
        //assertEq(royaltyModule.royaltyPolicies(address(derivIpa)), address(royaltyPolicyLAP));
        // RoyaltyPolicyLAP
        assertTrue(royaltyPolicyLAP.paused());
        (
            bool unlinkable,
            address vault,
            uint32 stack,
            address[] memory ancestors,
            uint32[] memory ancestorsRoyalty
        ) = royaltyPolicyLAP.getRoyaltyData(address(ipa));

        IRoyaltyPolicyLAP.LAPRoyaltyData memory newIpaData = IRoyaltyPolicyLAP.LAPRoyaltyData({
            // whether calling via minting license or linking to parents the ipId becomes unlinkable
            isUnlinkableToParents: unlinkable,
            ipRoyaltyVault: vault,
            royaltyStack: stack,
            ancestorsAddresses: ancestors,
            ancestorsRoyalties: ancestorsRoyalty
        });

        assertEq(newIpaData.isUnlinkableToParents, ipaRoyaltyData.isUnlinkableToParents);
        assertEq(newIpaData.ipRoyaltyVault, ipaRoyaltyData.ipRoyaltyVault);
        assertEq(newIpaData.royaltyStack, ipaRoyaltyData.royaltyStack);
        //assertEq(newIpaData.ancestorsAddresses[0], ipaRoyaltyData.ancestorsAddresses[0]);
        assertEq(newIpaData.ancestorsAddresses.length, ipaRoyaltyData.ancestorsAddresses.length);
        //assertEq(newIpaData.ancestorsRoyalties[0], ipaRoyaltyData.ancestorsRoyalties[0]);
        assertEq(newIpaData.ancestorsRoyalties.length, ipaRoyaltyData.ancestorsRoyalties.length);

        // IpRoyaltyVault
        // TODO

        // License system
        // LicenseRegistry_V1_0_0 internal licenseRegistry;
        LicenseRegistry licReg_V1_1_0 = LicenseRegistry(address(licenseRegistry));
        assertEq(address(licensingModule), address(licReg_V1_1_0.LICENSING_MODULE()));
        assertEq(address(disputeModule), address(licReg_V1_1_0.DISPUTE_MODULE()));
        (address defLT, uint256 defLTID) = licenseRegistry.getDefaultLicenseTerms();
        assertEq(defLT, address(pilTemplate));
        assertEq(defLTID, defaultTermsId);
        assertTrue(licReg_V1_1_0.isRegisteredLicenseTemplate(address(pilTemplate)));
        assertTrue(licReg_V1_1_0.isDerivativeIp(address(derivIpa)));
        assertTrue(licReg_V1_1_0.hasDerivativeIps(address(ipa)));
        assertTrue(licReg_V1_1_0.exists(address(pilTemplate), termsId));
        assertTrue(licReg_V1_1_0.exists(address(pilTemplate), defaultTermsId));
        assertTrue(licReg_V1_1_0.hasIpAttachedLicenseTerms(address(ipa), address(pilTemplate), termsId));

        (address attLT, uint256 attLicenseTermsId) = licReg_V1_1_0.getAttachedLicenseTerms(address(ipa), 0);
        assertEq(attLT, address(pilTemplate));
        assertEq(attLicenseTermsId, 2);
        assertEq(licReg_V1_1_0.getAttachedLicenseTermsCount(address(ipa)), 1);

        (attLT, attLicenseTermsId) = licReg_V1_1_0.getAttachedLicenseTerms(address(derivIpa), 0);
        assertEq(attLT, address(pilTemplate));
        assertEq(attLicenseTermsId, 2);
        assertEq(licReg_V1_1_0.getAttachedLicenseTermsCount(address(derivIpa)), 1);

        assertEq(licenseRegistry.getDerivativeIp(address(ipa), 0), address(derivIpa));
        assertEq(licenseRegistry.getDerivativeIpCount(address(ipa)), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(address(derivIpa)), 0);

        assertEq(licenseRegistry.getParentIp(address(derivIpa), 0), address(ipa));
        assertEq(licenseRegistry.getParentIpCount(address(derivIpa)), 1);

        // TODO: Set v1.0.0 minting config first
        // Licensing.LicensingConfig memory ipaConfig =
        // licReg_V1_1_0.getLicensingConfig(address(ipa), address(pilTemplate), termsId);
        // assertEq(ipaConfig.isSet, ipaLicConfig.isSet);
        // assertEq(ipaConfig.mintingFee, ipaLicConfig.mintingFee);
        // assertEq(ipaConfig.licensingHook, ipaLicConfig.mintingFeeModule);
        // assertEq(ipaConfig.hookData, ipaLicConfig.receiverCheckData);

        LicensingModule licMod_V1_1_0 = LicensingModule(address(licensingModule));
        assertTrue(licMod_V1_1_0.paused());

        // LicenseToken_V1_0_0 internal licenseToken;
        LicenseToken licTok_V1_1_0 = LicenseToken(address(licenseToken));
        assertEq(licTok_V1_1_0.totalSupply(), 3);
        assertEq(licTok_V1_1_0.balanceOf(ipaOwner), 2);
        assertEq(licTok_V1_1_0.totalMintedTokens(), 3);
        // TODO compare token metadata
        assertEq(licTok_V1_1_0.getLicensorIpId(1), address(ipa));
        assertEq(licTok_V1_1_0.getLicensorIpId(2), address(ipa));

        assertEq(licTok_V1_1_0.getLicenseTermsId(1), 2);
        assertEq(licTok_V1_1_0.getLicenseTermsId(2), 1);
        assertEq(licTok_V1_1_0.getLicenseTermsId(3), 0);
        assertEq(licTok_V1_1_0.getLicenseTemplate(1), address(pilTemplate));
        assertEq(licTok_V1_1_0.getLicenseTemplate(2), address(pilTemplate));
        assertEq(licTok_V1_1_0.isLicenseTokenRevoked(1), true);

        PILicenseTemplate pilTemp_V1_1_0 = PILicenseTemplate(address(pilTemplate));
        assertFalse(pilTemp_V1_1_0.isLicenseTransferable(1));
        assertTrue(pilTemp_V1_1_0.isLicenseTransferable(2));
        assertEq(pilTemp_V1_1_0.getLicenseTermsId(convertPILTerms(terms)), 2);
        // TODO: This check should be equal, currently failing
        // assertEq(pilTemp_V1_1_0.getLicenseTermsId(convertPILTerms(defaultTerms)), defaultTermsId);
        assertEq(pilTemp_V1_1_0.getLicenseTermsURI(1), ""); // TODO check this without using PILFlavors
        // TODO: compare getRoyaltyPolicy results
        // TODO: check expireTerms
    }

    function convertPILTerms(PILTerms_V1_0_0 memory t) internal returns (PILTerms memory) {
        return
            PILTerms({
                transferable: t.transferable,
                royaltyPolicy: t.royaltyPolicy,
                mintingFee: t.mintingFee,
                expiration: t.expiration,
                commercialUse: t.commercialUse,
                commercialAttribution: t.commercialAttribution,
                commercializerChecker: t.commercializerChecker,
                commercializerCheckerData: t.commercializerCheckerData,
                commercialRevShare: t.commercialRevShare,
                commercialRevCelling: t.commercialRevCelling,
                derivativesAllowed: t.derivativesAllowed,
                derivativesAttribution: t.derivativesAttribution,
                derivativesApproval: t.derivativesApproval,
                derivativesReciprocal: t.derivativesReciprocal,
                derivativeRevCelling: t.derivativeRevCelling,
                currency: t.currency,
                uri: t.uri
            });
    }

    function upgrade(UpgradedImplHelper.UpgradeProposal memory prop) internal {
        console2.log("Upgrading");
        console2.log(prop.key);
        if (keccak256(abi.encodePacked(prop.key)) == keccak256(abi.encodePacked("IpRoyaltyVault"))) {
            upgradeVaults(prop);
        } else {
            upgradeUUPS(prop);
        }
    }

    function upgradeUUPS(UpgradedImplHelper.UpgradeProposal memory prop) internal {
        // console2.log(address(protocolAccessManager));
        (bool immediate, uint32 delay) = protocolAccessManager.canCall(
            u.admin,
            address(prop.proxy),
            UUPSUpgradeable.upgradeToAndCall.selector
        );

        // console2.log(string.concat("Can call schedule: ", immediate ? "true" : "false"));
        // console2.log("with delay");
        // console2.log(delay);

        (immediate, delay) = protocolAccessManager.canCall(
            u.admin,
            address(protocolAccessManager),
            AccessManager.schedule.selector
        );

        // console2.log(string.concat("Can call upgrade: ", immediate ? "true" : "false"));
        // console2.log("with delay");
        // console2.log(delay);

        vm.prank(u.admin);
        (bytes32 operationId, uint32 nonce) = protocolAccessManager.schedule(
            prop.proxy,
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (prop.newImpl, "")),
            0 // earliest time possible, upgraderExecDelay
        );
        console2.log("----");
        console2.log("key");
        console2.log(prop.key);
        console2.log("proxy");
        console2.log(address(prop.proxy));
        console2.log("encodedCall");
        console2.logBytes(abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (prop.newImpl, "")));
        console2.log("----");


        uint48 schedule = protocolAccessManager.getSchedule(operationId);

        (immediate, delay) = protocolAccessManager.canCall(
            u.admin,
            address(prop.proxy),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        vm.warp(block.timestamp + delay + 1);
        // console2.log(string.concat("Can call upgrade: ", immediate ? "true" : "false"));
        // console2.log("with delay");
        // console2.log(delay);

        vm.prank(u.admin);
        UUPSUpgradeable(prop.proxy).upgradeToAndCall(prop.newImpl, "");
    }

    function upgradeVaults(UpgradedImplHelper.UpgradeProposal memory prop) internal {
        vm.prank(u.admin);
        (bytes32 operationId, uint32 nonce) = protocolAccessManager.schedule(
            prop.proxy,
            abi.encodeCall(RoyaltyPolicyLAP.upgradeVaults, prop.newImpl),
            0 // earliest time possible, upgraderExecDelay
        );
        console2.log("----");
        console2.log("key");
        console2.log(prop.key);
        console2.log("proxy");
        console2.log(address(prop.proxy));
        console2.log("encodedCall");
        console2.logBytes(abi.encodeCall(RoyaltyPolicyLAP.upgradeVaults, prop.newImpl));
        console2.log("----");
        (bool immediate, uint32 delay) = protocolAccessManager.canCall(
            u.admin,
            address(prop.proxy),
            RoyaltyPolicyLAP.upgradeVaults.selector
        );

        vm.warp(block.timestamp + delay + 1);
        vm.prank(u.admin);
        RoyaltyPolicyLAP(prop.proxy).upgradeVaults(prop.newImpl);
    }

    function dealMockAssets() public {
        erc20.mint(u.alice, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.bob, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.carl, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.dan, 1000 * 10 ** erc20.decimals());

        erc20bb.mint(u.alice, 1000 * 10 ** erc20bb.decimals());
        erc20bb.mint(u.bob, 1000 * 10 ** erc20bb.decimals());
        erc20bb.mint(u.carl, 1000 * 10 ** erc20bb.decimals());
        erc20bb.mint(u.dan, 1000 * 10 ** erc20bb.decimals());
    }
}
