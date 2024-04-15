/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { CREATE3 } from "@solady/src/utils/CREATE3.sol";

// contracts
import { ProtocolPauseAdmin } from "contracts/pause/ProtocolPauseAdmin.sol";
import { ProtocolPausableUpgradeable } from "contracts/pause/ProtocolPausableUpgradeable.sol";
import { AccessController } from "contracts/access/AccessController.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IRoyaltyPolicyLAP } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { PILFlavors } from "contracts/lib/PILFlavors.sol";
// solhint-disable-next-line max-line-length
import { DISPUTE_MODULE_KEY, ROYALTY_MODULE_KEY, LICENSING_MODULE_KEY, TOKEN_WITHDRAWAL_MODULE_KEY, CORE_METADATA_MODULE_KEY, CORE_METADATA_VIEW_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { DisputeModule } from "contracts/modules/dispute/DisputeModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute/policies/ArbitrationPolicySP.sol";
import { TokenWithdrawalModule } from "contracts/modules/external/TokenWithdrawalModule.sol";
import { MODULE_TYPE_HOOK } from "contracts/lib/modules/Module.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IHookModule } from "contracts/interfaces/modules/base/IHookModule.sol";
import { IpRoyaltyVault } from "contracts/modules/royalty/policies/IpRoyaltyVault.sol";
import { CoreMetadataModule } from "contracts/modules/metadata/CoreMetadataModule.sol";
import { CoreMetadataViewModule } from "contracts/modules/metadata/CoreMetadataViewModule.sol";
import { PILicenseTemplate, PILTerms } from "contracts/modules/licensing/PILicenseTemplate.sol";
import { LicenseToken } from "contracts/LicenseToken.sol";

// script
import { StringUtil } from "./StringUtil.sol";
import { BroadcastManager } from "./BroadcastManager.s.sol";
import { StorageLayoutChecker } from "./upgrades/StorageLayoutCheck.s.sol";
import { JsonDeploymentHandler } from "./JsonDeploymentHandler.s.sol";

// test
import { TestProxyHelper } from "test/foundry/utils/TestProxyHelper.sol";

contract DeployHelper is Script, BroadcastManager, JsonDeploymentHandler, StorageLayoutChecker {
    using StringUtil for uint256;
    using stdJson for string;

    error RoleConfigError(string message);

    ERC6551Registry internal immutable erc6551Registry;
    IPAccountImpl internal ipAccountImpl;

    // Registry
    IPAssetRegistry internal ipAssetRegistry;
    LicenseRegistry internal licenseRegistry;
    ModuleRegistry internal moduleRegistry;

    // Core Module
    LicensingModule internal licensingModule;
    DisputeModule internal disputeModule;
    RoyaltyModule internal royaltyModule;
    CoreMetadataModule internal coreMetadataModule;

    // External Module
    CoreMetadataViewModule internal coreMetadataViewModule;
    TokenWithdrawalModule internal tokenWithdrawalModule;

    // Policy
    ArbitrationPolicySP internal arbitrationPolicySP;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    UpgradeableBeacon internal ipRoyaltyVaultBeacon;
    IpRoyaltyVault internal ipRoyaltyVaultImpl;

    // Access Control
    AccessManager internal protocolAccessManager; // protocol roles
    AccessController internal accessController; // per IPA roles

    // Pause
    ProtocolPauseAdmin internal protocolPauser;

    // License system
    LicenseToken internal licenseToken;
    PILicenseTemplate internal pilTemplate;

    // Token
    ERC20 private immutable erc20; // keep private to avoid conflict with inheriting contracts

    // keep private to avoid conflict with inheriting contracts
    uint256 private immutable ARBITRATION_PRICE;
    uint256 private immutable MAX_ROYALTY_APPROVAL;

    // DeployHelper variable
    bool private writeDeploys;

    constructor(
        address erc6551Registry_,
        address erc20_,
        uint256 arbitrationPrice_,
        uint256 maxRoyaltyApproval_
    ) JsonDeploymentHandler("main") {
        erc6551Registry = ERC6551Registry(erc6551Registry_);
        erc20 = ERC20(erc20_);
        ARBITRATION_PRICE = arbitrationPrice_;
        MAX_ROYALTY_APPROVAL = maxRoyaltyApproval_;

        /// @dev USDC addresses are fetched from
        /// (mainnet) https://developers.circle.com/stablecoins/docs/usdc-on-main-networks
        /// (testnet) https://developers.circle.com/stablecoins/docs/usdc-on-test-networks
        if (block.chainid == 1) erc20 = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        else if (block.chainid == 11155111) erc20 = ERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    }

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run(bool runStorageLayoutCheck, bool writeDeploys_) public virtual {
        writeDeploys = writeDeploys_;

        // This will run OZ storage layout check for all contracts. Requires --ffi flag.
        if (runStorageLayoutCheck) super.run();

        _beginBroadcast(); // BroadcastManager.s.sol

        _deployProtocolContracts();
        _configureDeployment();
        _configureRoles();

        // Check role assignment.
        (bool deployerIsAdmin, ) = protocolAccessManager.hasRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, deployer);
        if (deployerIsAdmin) {
            revert RoleConfigError("Deployer did not renounce admin role");
        }
        (bool multisigAdmin, ) = protocolAccessManager.hasRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, multisig);
        (bool multisigUpgrader, ) = protocolAccessManager.hasRole(ProtocolAdmin.UPGRADER_ROLE, multisig);

        if (address(royaltyPolicyLAP) != ipRoyaltyVaultBeacon.owner()) {
            revert RoleConfigError("RoyaltyPolicyLAP is not owner of IpRoyaltyVaultBeacon");
        }

        if (!multisigAdmin || !multisigUpgrader) {
            revert RoleConfigError("Multisig roles not granted");
        }

        if (writeDeploys) _writeDeployment();
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function create3Deploy(bytes32 salt, bytes calldata creationCode, uint256 value) external returns (address) {
        return CREATE3.deploy(salt, creationCode, value);
    }

    function _deployProtocolContracts() private {
        require(address(erc20) != address(0), "Deploy: Asset Not Set");
        bytes32 ipAccountImplSalt = keccak256(
            abi.encode(type(IPAccountImpl).creationCode, address(this), block.timestamp)
        );
        address ipAccountImplAddr = CREATE3.getDeployed(ipAccountImplSalt);

        string memory contractKey;

        // Core Protocol Contracts

        contractKey = "ProtocolAccessManager";
        _predeploy(contractKey);
        protocolAccessManager = new AccessManager(deployer);
        _postdeploy(contractKey, address(protocolAccessManager));

        contractKey = "ProtocolPauseAdmin";
        _predeploy(contractKey);
        protocolPauser = new ProtocolPauseAdmin(address(protocolAccessManager));
        _postdeploy(contractKey, address(protocolPauser));

        contractKey = "AccessController";
        _predeploy(contractKey);

        address impl = address(new AccessController());
        accessController = AccessController(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(AccessController.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(accessController));

        contractKey = "ModuleRegistry";
        _predeploy(contractKey);
        impl = address(new ModuleRegistry());
        moduleRegistry = ModuleRegistry(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(ModuleRegistry.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(moduleRegistry));

        contractKey = "IPAssetRegistry";
        _predeploy(contractKey);
        impl = address(new IPAssetRegistry(address(erc6551Registry), ipAccountImplAddr));
        ipAssetRegistry = IPAssetRegistry(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(IPAssetRegistry.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(ipAssetRegistry));

        IPAccountRegistry ipAccountRegistry = IPAccountRegistry(address(ipAssetRegistry));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        impl = address(new LicenseRegistry());
        licenseRegistry = LicenseRegistry(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(LicenseRegistry.initialize, (address(protocolAccessManager)))
            )
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "IPAccountImpl";
        bytes memory ipAccountImplCode = abi.encodePacked(
            type(IPAccountImpl).creationCode,
            abi.encode(
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(moduleRegistry)
            )
        );
        _predeploy(contractKey);
        this.create3Deploy(ipAccountImplSalt, ipAccountImplCode, 0);
        ipAccountImpl = IPAccountImpl(payable(ipAccountImplAddr));
        _postdeploy(contractKey, address(ipAccountImpl));

        contractKey = "DisputeModule";
        _predeploy(contractKey);
        impl = address(new DisputeModule(address(accessController), address(ipAssetRegistry), address(licenseRegistry)));
        disputeModule = DisputeModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(DisputeModule.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0);
        _postdeploy(contractKey, address(disputeModule));

        contractKey = "LicenseToken";
        _predeploy(contractKey);
        impl = address(new LicenseToken());
        licenseToken = LicenseToken(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(
                    LicenseToken.initialize,
                    (
                        address(protocolAccessManager),
                        "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"
                    )
                )
            )
        );
        impl = address(0);
        _postdeploy(contractKey, address(licenseToken));

        contractKey = "RoyaltyModule";
        _predeploy(contractKey);
        impl = address(new RoyaltyModule(address(disputeModule), address(licenseRegistry)));
        royaltyModule = RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyModule.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0);
        _postdeploy(contractKey, address(royaltyModule));

        contractKey = "LicensingModule";
        _predeploy(contractKey);
        impl = address(
            new LicensingModule(
                address(accessController),
                address(ipAccountRegistry),
                address(royaltyModule),
                address(licenseRegistry),
                address(disputeModule),
                address(licenseToken)
            )
        );
        licensingModule = LicensingModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(LicensingModule.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(licensingModule));

        //
        // Story-specific Non-Core Contracts
        //

        _predeploy("ArbitrationPolicySP");
        impl = address(new ArbitrationPolicySP(address(disputeModule), address(erc20), ARBITRATION_PRICE));
        arbitrationPolicySP = ArbitrationPolicySP(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(ArbitrationPolicySP.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0);
        _postdeploy("ArbitrationPolicySP", address(arbitrationPolicySP));

        _predeploy("RoyaltyPolicyLAP");
        impl = address(new RoyaltyPolicyLAP(address(royaltyModule), address(licensingModule)));
        royaltyPolicyLAP = RoyaltyPolicyLAP(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyPolicyLAP.initialize, address(protocolAccessManager))
            )
        );
        impl = address(0);
        _postdeploy("RoyaltyPolicyLAP", address(royaltyPolicyLAP));

        _predeploy("PILicenseTemplate");
        impl = address(
            new PILicenseTemplate(
                address(accessController),
                address(ipAccountRegistry),
                address(licenseRegistry),
                address(royaltyModule)
            )
        );
        pilTemplate = PILicenseTemplate(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(
                    PILicenseTemplate.initialize,
                    (
                        address(protocolAccessManager),
                        "pil",
                        "https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf"
                    )
                )
            )
        );
        impl = address(0);
        _postdeploy("PILicenseTemplate", address(pilTemplate));

        _predeploy("IpRoyaltyVaultImpl");
        ipRoyaltyVaultImpl = new IpRoyaltyVault(address(royaltyPolicyLAP), address(disputeModule));
        _postdeploy("IpRoyaltyVaultImpl", address(ipRoyaltyVaultImpl));

        _predeploy("IpRoyaltyVaultBeacon");
        // Transfer Ownership to RoyaltyPolicyLAP later
        ipRoyaltyVaultBeacon = new UpgradeableBeacon(address(ipRoyaltyVaultImpl), deployer);
        _postdeploy("IpRoyaltyVaultBeacon", address(ipRoyaltyVaultBeacon));

        _predeploy("CoreMetadataModule");
        coreMetadataModule = new CoreMetadataModule(address(accessController), address(ipAssetRegistry));
        _postdeploy("CoreMetadataModule", address(coreMetadataModule));

        _predeploy("CoreMetadataViewModule");
        coreMetadataViewModule = new CoreMetadataViewModule(address(ipAssetRegistry), address(moduleRegistry));
        _postdeploy("CoreMetadataViewModule", address(coreMetadataViewModule));

        _predeploy("TokenWithdrawalModule");
        tokenWithdrawalModule = new TokenWithdrawalModule(address(accessController), address(ipAccountRegistry));
        _postdeploy("TokenWithdrawalModule", address(tokenWithdrawalModule));
    }

    function _predeploy(string memory contractKey) private view {
        if (writeDeploys) console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        if (writeDeploys) {
            _writeAddress(contractKey, newAddress);
            console2.log(string.concat(contractKey, " deployed to:"), newAddress);
        }
    }

    function _configureDeployment() private {
        IPAccountRegistry ipAccountRegistry = IPAccountRegistry(address(ipAssetRegistry));

        // Protocol Pause
        protocolPauser.addPausable(address(accessController));
        protocolPauser.addPausable(address(disputeModule));
        protocolPauser.addPausable(address(licensingModule));
        protocolPauser.addPausable(address(royaltyModule));
        protocolPauser.addPausable(address(royaltyPolicyLAP));
        protocolPauser.addPausable(address(ipAssetRegistry));
        

        // Module Registry
        moduleRegistry.registerModule(DISPUTE_MODULE_KEY, address(disputeModule));
        moduleRegistry.registerModule(LICENSING_MODULE_KEY, address(licensingModule));
        moduleRegistry.registerModule(ROYALTY_MODULE_KEY, address(royaltyModule));
        moduleRegistry.registerModule(CORE_METADATA_MODULE_KEY, address(coreMetadataModule));
        moduleRegistry.registerModule(CORE_METADATA_VIEW_MODULE_KEY, address(coreMetadataViewModule));
        moduleRegistry.registerModule(TOKEN_WITHDRAWAL_MODULE_KEY, address(tokenWithdrawalModule));

        // License Registry
        licenseRegistry.setDisputeModule(address(disputeModule));
        licenseRegistry.setLicensingModule(address(licensingModule));

        // License Token
        licenseToken.setDisputeModule(address(disputeModule));
        licenseToken.setLicensingModule(address(licensingModule));

        // Access Controller
        accessController.setAddresses(address(ipAccountRegistry), address(moduleRegistry));

        // Royalty Module and SP Royalty Policy
        royaltyModule.setLicensingModule(address(licensingModule));
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);
        royaltyPolicyLAP.setSnapshotInterval(7 days);
        royaltyPolicyLAP.setIpRoyaltyVaultBeacon(address(ipRoyaltyVaultBeacon));
        ipRoyaltyVaultBeacon.transferOwnership(address(royaltyPolicyLAP));

        // Dispute Module and SP Dispute Policy
        address arbitrationRelayer = relayer;
        disputeModule.whitelistDisputeTag("PLAGIARISM", true);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), arbitrationRelayer, true);
        disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP));

        // Core Metadata Module
        coreMetadataViewModule.updateCoreMetadataModule();

        // License Template
        licenseRegistry.registerLicenseTemplate(address(pilTemplate));
    }

    function _configureRoles() private {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;

        ///////// Role Configuration /////////
        // Upgrades
        protocolAccessManager.labelRole(ProtocolAdmin.UPGRADER_ROLE, ProtocolAdmin.UPGRADER_ROLE_LABEL);
        // Note: upgraderExecDelay is set in BroadcastManager.sol
        protocolAccessManager.setTargetFunctionRole(address(licenseToken), selectors, ProtocolAdmin.UPGRADER_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(accessController), selectors, ProtocolAdmin.UPGRADER_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(disputeModule), selectors, ProtocolAdmin.UPGRADER_ROLE);
        protocolAccessManager.setTargetFunctionRole(
            address(arbitrationPolicySP),
            selectors,
            ProtocolAdmin.UPGRADER_ROLE
        );
        protocolAccessManager.setTargetFunctionRole(address(licensingModule), selectors, ProtocolAdmin.UPGRADER_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(royaltyModule), selectors, ProtocolAdmin.UPGRADER_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(licenseRegistry), selectors, ProtocolAdmin.UPGRADER_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(moduleRegistry), selectors, ProtocolAdmin.UPGRADER_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(ipAssetRegistry), selectors, ProtocolAdmin.UPGRADER_ROLE);

        // Royalty and Upgrade Beacon
        // Owner of the beacon is the RoyaltyPolicyLAP
        selectors = new bytes4[](2);
        selectors[0] = RoyaltyPolicyLAP.upgradeVaults.selector;
        selectors[1] = UUPSUpgradeable.upgradeToAndCall.selector;
        protocolAccessManager.setTargetFunctionRole(address(royaltyPolicyLAP), selectors, ProtocolAdmin.UPGRADER_ROLE);

        // Pause
        selectors = new bytes4[](2);
        selectors[0] = ProtocolPausableUpgradeable.pause.selector;
        selectors[1] = ProtocolPausableUpgradeable.unpause.selector;

        protocolAccessManager.labelRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, ProtocolAdmin.PAUSE_ADMIN_ROLE_LABEL);
        protocolAccessManager.setTargetFunctionRole(address(accessController), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(disputeModule), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(licensingModule), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(royaltyModule), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(royaltyPolicyLAP), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(ipAssetRegistry), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(licenseRegistry), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(address(protocolPauser), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        ///////// Role Granting /////////
        protocolAccessManager.grantRole(ProtocolAdmin.UPGRADER_ROLE, multisig, upgraderExecDelay);
        protocolAccessManager.grantRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, multisig, 0);
        protocolAccessManager.grantRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, address(protocolPauser), 0);
        protocolAccessManager.grantRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, multisig, 0);

        ///////// Renounce admin role /////////
        protocolAccessManager.renounceRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, deployer);
    }
}
