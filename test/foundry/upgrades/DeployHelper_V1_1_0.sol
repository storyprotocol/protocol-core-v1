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

// contracts
// solhint-disable-next-line max-line-length
import { AccessController_V1_0_0, IPAccountImpl_V1_0_0, DISPUTE_MODULE_KEY, ROYALTY_MODULE_KEY, LICENSING_MODULE_KEY, TOKEN_WITHDRAWAL_MODULE_KEY, CORE_METADATA_MODULE_KEY, CORE_METADATA_VIEW_MODULE_KEY, IPAccountRegistry_V1_0_0, IPAssetRegistry_V1_0_0, LicenseRegistry_V1_0_0, LicensingModule_V1_0_0, RoyaltyModule_V1_0_0, RoyaltyPolicyLAP_V1_0_0, DisputeModule_V1_0_0, IpRoyaltyVault_V1_0_0, PILicenseTemplate_V1_0_0, LicenseToken_V1_0_0 } from "../../../contracts/old/v1.0.0.sol";

import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { CoreMetadataModule } from "contracts/modules/metadata/CoreMetadataModule.sol";
import { CoreMetadataViewModule } from "contracts/modules/metadata/CoreMetadataViewModule.sol";
import { TokenWithdrawalModule } from "contracts/modules/external/TokenWithdrawalModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute/policies/ArbitrationPolicySP.sol";
import { ProtocolPauseAdmin } from "contracts/pause/ProtocolPauseAdmin.sol";
import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";
import { ProtocolPausableUpgradeable } from "contracts/pause/ProtocolPausableUpgradeable.sol";

// script
import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "../../../script/foundry/utils/BroadcastManager.s.sol";
import { StorageLayoutChecker } from "../../../script/foundry/utils/upgrades/StorageLayoutCheck.s.sol";
import { JsonDeploymentHandler } from "../../../script/foundry/utils/JsonDeploymentHandler.s.sol";

// test
import { TestProxyHelper } from "test/foundry/utils/TestProxyHelper.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";

contract DeployHelper_V1_1_0 is Script, BroadcastManager, JsonDeploymentHandler, StorageLayoutChecker {
    using StringUtil for uint256;
    using stdJson for string;

    // PROXY 1967 IMPLEMENTATION STORAGE SLOTS
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    error RoleConfigError(string message);

    ERC6551Registry internal immutable erc6551Registry;
    ICreate3Deployer internal immutable create3Deployer;
    // seed for CREATE3 salt
    uint256 internal create3SaltSeed;
    IPAccountImpl_V1_0_0 internal ipAccountImpl;

    // Registry
    IPAssetRegistry_V1_0_0 internal ipAssetRegistry;
    LicenseRegistry_V1_0_0 internal licenseRegistry;
    ModuleRegistry internal moduleRegistry;

    // Core Module
    LicensingModule_V1_0_0 internal licensingModule;
    DisputeModule_V1_0_0 internal disputeModule;
    RoyaltyModule_V1_0_0 internal royaltyModule;
    CoreMetadataModule internal coreMetadataModule;

    // External Module
    CoreMetadataViewModule internal coreMetadataViewModule;
    TokenWithdrawalModule internal tokenWithdrawalModule;

    // Policy
    ArbitrationPolicySP internal arbitrationPolicySP;
    RoyaltyPolicyLAP_V1_0_0 internal royaltyPolicyLAP;
    UpgradeableBeacon internal ipRoyaltyVaultBeacon;
    IpRoyaltyVault_V1_0_0 internal ipRoyaltyVaultImpl;

    // Access Control
    AccessManager internal protocolAccessManager; // protocol roles
    AccessController_V1_0_0 internal accessController; // per IPA roles

    // Pause
    ProtocolPauseAdmin internal protocolPauser;

    // License system
    LicenseToken_V1_0_0 internal licenseToken;
    PILicenseTemplate_V1_0_0 internal pilTemplate;

    // Token
    ERC20 private immutable erc20; // keep private to avoid conflict with inheriting contracts

    // keep private to avoid conflict with inheriting contracts
    uint256 private immutable ARBITRATION_PRICE;
    uint256 private immutable MAX_ROYALTY_APPROVAL;

    // DeployHelper variable
    bool private writeDeploys;

    constructor(
        address erc6551Registry_,
        address create3Deployer_,
        address erc20_,
        uint256 arbitrationPrice_,
        uint256 maxRoyaltyApproval_
    ) JsonDeploymentHandler("main") {
        erc6551Registry = ERC6551Registry(erc6551Registry_);
        create3Deployer = ICreate3Deployer(create3Deployer_);
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

    function run(uint256 create3SaltSeed_, bool runStorageLayoutCheck, bool writeDeploys_) public virtual {
        create3SaltSeed = create3SaltSeed_;
        writeDeploys = writeDeploys_;

        // This will run OZ storage layout check for all contracts. Requires --ffi flag.
        if (runStorageLayoutCheck) _validate();

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
        if (!multisigAdmin) {
            revert RoleConfigError("Multisig admin role not granted");
        }
        if (!multisigUpgrader) {
            revert RoleConfigError("Multisig upgrader role not granted");
        }

        if (writeDeploys) _writeDeployment();

        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _getSalt(string memory name) internal view returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, create3SaltSeed));
    }

    function _deployProtocolContracts() private {
        require(address(erc20) != address(0), "Deploy: Asset Not Set");
        string memory contractKey;
        // Core Protocol Contracts
        contractKey = "ProtocolAccessManager";
        _predeploy(contractKey);
        protocolAccessManager = AccessManager(
            create3Deployer.deploy(
                _getSalt(type(AccessManager).name),
                abi.encodePacked(type(AccessManager).creationCode, abi.encode(deployer))
            )
        );
        require(
            _getDeployedAddress(type(AccessManager).name) == address(protocolAccessManager),
            "Deploy: Protocol Access Manager Address Mismatch"
        );
        _postdeploy(contractKey, address(protocolAccessManager));

        contractKey = "ProtocolPauseAdmin";
        _predeploy(contractKey);
        protocolPauser = ProtocolPauseAdmin(
            create3Deployer.deploy(
                _getSalt(type(ProtocolPauseAdmin).name),
                abi.encodePacked(type(ProtocolPauseAdmin).creationCode, abi.encode(address(protocolAccessManager)))
            )
        );
        require(
            _getDeployedAddress(type(ProtocolPauseAdmin).name) == address(protocolPauser),
            "Deploy: Protocol Pause Admin Address Mismatch"
        );
        _postdeploy(contractKey, address(protocolPauser));

        contractKey = "ModuleRegistry";
        _predeploy(contractKey);
        address impl = address(new ModuleRegistry());
        moduleRegistry = ModuleRegistry(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(ModuleRegistry).name),
                impl,
                abi.encodeCall(ModuleRegistry.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(ModuleRegistry).name) == address(moduleRegistry),
            "Deploy: Module Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(moduleRegistry)) == impl, "ModuleRegistry Proxy Implementation Mismatch");
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(moduleRegistry));

        contractKey = "IPAssetRegistry";
        _predeploy(contractKey);
        impl = address(
            new IPAssetRegistry_V1_0_0(address(erc6551Registry), _getDeployedAddress(type(IPAccountImpl_V1_0_0).name))
        );
        ipAssetRegistry = IPAssetRegistry_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(IPAssetRegistry_V1_0_0).name),
                impl,
                abi.encodeCall(IPAssetRegistry_V1_0_0.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(IPAssetRegistry_V1_0_0).name) == address(ipAssetRegistry),
            "Deploy: IP Asset Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(ipAssetRegistry)) == impl, "IPAssetRegistry Proxy Implementation Mismatch");
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(ipAssetRegistry));

        IPAccountRegistry_V1_0_0 ipAccountRegistry = IPAccountRegistry_V1_0_0(address(ipAssetRegistry));

        contractKey = "AccessController";
        _predeploy(contractKey);
        impl = address(new AccessController_V1_0_0());
        accessController = AccessController_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(AccessController_V1_0_0).name),
                impl,
                abi.encodeCall(AccessController_V1_0_0.initialize, address(protocolAccessManager))
            )
        );
        accessController.setAddresses(address(ipAssetRegistry), address(moduleRegistry));

        require(
            _getDeployedAddress(type(AccessController_V1_0_0).name) == address(accessController),
            "Deploy: Access Controller Address Mismatch"
        );
        require(_loadProxyImpl(address(accessController)) == impl, "AccessController Proxy Implementation Mismatch");
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(accessController));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        impl = address(new LicenseRegistry_V1_0_0());
        licenseRegistry = LicenseRegistry_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(LicenseRegistry_V1_0_0).name),
                impl,
                abi.encodeCall(LicenseRegistry_V1_0_0.initialize, (address(protocolAccessManager)))
            )
        );
        licenseRegistry.setDisputeModule(_getDeployedAddress(type(DisputeModule_V1_0_0).name));
        licenseRegistry.setLicensingModule(_getDeployedAddress(type(LicensingModule_V1_0_0).name));
        require(
            _getDeployedAddress(type(LicenseRegistry_V1_0_0).name) == address(licenseRegistry),
            "Deploy: License Registry Address Mismatch"
        );
        require(_loadProxyImpl(address(licenseRegistry)) == impl, "LicenseRegistry Proxy Implementation Mismatch");
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "IPAccountImpl";
        bytes memory ipAccountImplCode = abi.encodePacked(
            type(IPAccountImpl_V1_0_0).creationCode,
            abi.encode(
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(moduleRegistry)
            )
        );
        _predeploy(contractKey);
        ipAccountImpl = IPAccountImpl_V1_0_0(
            payable(create3Deployer.deploy(_getSalt(type(IPAccountImpl_V1_0_0).name), ipAccountImplCode))
        );
        _postdeploy(contractKey, address(ipAccountImpl));
        require(
            _getDeployedAddress(type(IPAccountImpl_V1_0_0).name) == address(ipAccountImpl),
            "Deploy: IP Account Impl Address Mismatch"
        );

        contractKey = "DisputeModule";
        _predeploy(contractKey);
        impl = address(
            new DisputeModule_V1_0_0(address(accessController), address(ipAssetRegistry), address(licenseRegistry))
        );
        disputeModule = DisputeModule_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(DisputeModule_V1_0_0).name),
                impl,
                abi.encodeCall(DisputeModule_V1_0_0.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(DisputeModule_V1_0_0).name) == address(disputeModule),
            "Deploy: Dispute Module Address Mismatch"
        );
        require(_loadProxyImpl(address(disputeModule)) == impl, "DisputeModule Proxy Implementation Mismatch");
        impl = address(0);
        _postdeploy(contractKey, address(disputeModule));

        contractKey = "RoyaltyModule";
        _predeploy(contractKey);
        impl = address(new RoyaltyModule_V1_0_0(address(disputeModule), address(licenseRegistry)));
        royaltyModule = RoyaltyModule_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyModule_V1_0_0).name),
                impl,
                abi.encodeCall(RoyaltyModule_V1_0_0.initialize, address(protocolAccessManager))
            )
        );
        royaltyModule.setLicensingModule(_getDeployedAddress(type(LicensingModule_V1_0_0).name));
        require(
            _getDeployedAddress(type(RoyaltyModule_V1_0_0).name) == address(royaltyModule),
            "Deploy: Royalty Module Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyModule)) == impl, "RoyaltyModule Proxy Implementation Mismatch");
        impl = address(0);
        _postdeploy(contractKey, address(royaltyModule));

        contractKey = "LicensingModule";
        _predeploy(contractKey);
        impl = address(
            new LicensingModule_V1_0_0(
                address(accessController),
                address(ipAccountRegistry),
                address(royaltyModule),
                address(licenseRegistry),
                address(disputeModule),
                _getDeployedAddress(type(LicenseToken_V1_0_0).name)
            )
        );
        licensingModule = LicensingModule_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(LicensingModule_V1_0_0).name),
                impl,
                abi.encodeCall(LicensingModule_V1_0_0.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(LicensingModule_V1_0_0).name) == address(licensingModule),
            "Deploy: Licensing Module Address Mismatch"
        );
        require(_loadProxyImpl(address(licensingModule)) == impl, "LicensingModule Proxy Implementation Mismatch");
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(licensingModule));

        contractKey = "LicenseToken";
        _predeploy(contractKey);
        impl = address(new LicenseToken_V1_0_0());
        licenseToken = LicenseToken_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(LicenseToken_V1_0_0).name),
                impl,
                abi.encodeCall(
                    LicenseToken_V1_0_0.initialize,
                    (
                        address(protocolAccessManager),
                        "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"
                    )
                )
            )
        );
        licenseToken.setLicensingModule(_getDeployedAddress(type(LicensingModule_V1_0_0).name));
        licenseToken.setDisputeModule(address(disputeModule));
        require(
            _getDeployedAddress(type(LicenseToken_V1_0_0).name) == address(licenseToken),
            "Deploy: License Token Address Mismatch"
        );
        require(_loadProxyImpl(address(licenseToken)) == impl, "LicenseToken Proxy Implementation Mismatch");
        impl = address(0);
        _postdeploy(contractKey, address(licenseToken));

        //
        // Story-specific Non-Core Contracts
        //

        _predeploy("ArbitrationPolicySP");
        impl = address(new ArbitrationPolicySP(address(disputeModule), address(erc20), ARBITRATION_PRICE));
        arbitrationPolicySP = ArbitrationPolicySP(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(ArbitrationPolicySP).name),
                impl,
                abi.encodeCall(ArbitrationPolicySP.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(ArbitrationPolicySP).name) == address(arbitrationPolicySP),
            "Deploy: Arbitration Policy Address Mismatch"
        );
        require(
            _loadProxyImpl(address(arbitrationPolicySP)) == impl,
            "ArbitrationPolicySP Proxy Implementation Mismatch"
        );
        impl = address(0);
        _postdeploy("ArbitrationPolicySP", address(arbitrationPolicySP));

        _predeploy("RoyaltyPolicyLAP");
        impl = address(new RoyaltyPolicyLAP_V1_0_0(address(royaltyModule), address(licensingModule)));
        royaltyPolicyLAP = RoyaltyPolicyLAP_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyPolicyLAP_V1_0_0).name),
                impl,
                abi.encodeCall(RoyaltyPolicyLAP_V1_0_0.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(RoyaltyPolicyLAP_V1_0_0).name) == address(royaltyPolicyLAP),
            "Deploy: Royalty Policy Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyPolicyLAP)) == impl, "RoyaltyPolicyLAP Proxy Implementation Mismatch");
        impl = address(0);
        _postdeploy("RoyaltyPolicyLAP", address(royaltyPolicyLAP));

        _predeploy("PILicenseTemplate");
        impl = address(
            new PILicenseTemplate_V1_0_0(
                address(accessController),
                address(ipAccountRegistry),
                address(licenseRegistry),
                address(royaltyModule)
            )
        );
        pilTemplate = PILicenseTemplate_V1_0_0(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(PILicenseTemplate_V1_0_0).name),
                impl,
                abi.encodeCall(
                    PILicenseTemplate_V1_0_0.initialize,
                    (
                        address(protocolAccessManager),
                        "pil",
                        "https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf"
                    )
                )
            )
        );
        require(
            _getDeployedAddress(type(PILicenseTemplate_V1_0_0).name) == address(pilTemplate),
            "Deploy: PI License Template Address Mismatch"
        );
        require(_loadProxyImpl(address(pilTemplate)) == impl, "PILicenseTemplate Proxy Implementation Mismatch");
        impl = address(0);
        _postdeploy("PILicenseTemplate", address(pilTemplate));

        _predeploy("IpRoyaltyVaultImpl");
        ipRoyaltyVaultImpl = IpRoyaltyVault_V1_0_0(
            create3Deployer.deploy(
                _getSalt(type(IpRoyaltyVault_V1_0_0).name),
                abi.encodePacked(
                    type(IpRoyaltyVault_V1_0_0).creationCode,
                    abi.encode(address(royaltyPolicyLAP), address(disputeModule))
                )
            )
        );
        _postdeploy("IpRoyaltyVaultImpl", address(ipRoyaltyVaultImpl));

        _predeploy("IpRoyaltyVaultBeacon");
        // Transfer Ownership to RoyaltyPolicyLAP later
        ipRoyaltyVaultBeacon = UpgradeableBeacon(
            create3Deployer.deploy(
                _getSalt(type(UpgradeableBeacon).name),
                abi.encodePacked(
                    type(UpgradeableBeacon).creationCode,
                    abi.encode(address(ipRoyaltyVaultImpl), deployer)
                )
            )
        );
        _postdeploy("IpRoyaltyVaultBeacon", address(ipRoyaltyVaultBeacon));

        _predeploy("CoreMetadataModule");
        coreMetadataModule = CoreMetadataModule(
            create3Deployer.deploy(
                _getSalt(type(CoreMetadataModule).name),
                abi.encodePacked(
                    type(CoreMetadataModule).creationCode,
                    abi.encode(address(accessController), address(ipAssetRegistry))
                )
            )
        );
        _postdeploy("CoreMetadataModule", address(coreMetadataModule));

        _predeploy("CoreMetadataViewModule");
        coreMetadataViewModule = CoreMetadataViewModule(
            create3Deployer.deploy(
                _getSalt(type(CoreMetadataViewModule).name),
                abi.encodePacked(
                    type(CoreMetadataViewModule).creationCode,
                    abi.encode(address(ipAssetRegistry), address(moduleRegistry))
                )
            )
        );
        _postdeploy("CoreMetadataViewModule", address(coreMetadataViewModule));

        _predeploy("TokenWithdrawalModule");
        tokenWithdrawalModule = TokenWithdrawalModule(
            create3Deployer.deploy(
                _getSalt(type(TokenWithdrawalModule).name),
                abi.encodePacked(
                    type(TokenWithdrawalModule).creationCode,
                    abi.encode(address(accessController), address(ipAccountRegistry))
                )
            )
        );
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
        console2.log("Configuring deployment...");

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

        // Royalty Module and SP Royalty Policy
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
        console2.log("Configuring roles...");
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
        protocolAccessManager.setTargetFunctionRole(address(pilTemplate), selectors, ProtocolAdmin.UPGRADER_ROLE);

        // Royalty and Upgrade Beacon
        // Owner of the beacon is the RoyaltyPolicyLAP
        selectors = new bytes4[](2);
        selectors[0] = RoyaltyPolicyLAP_V1_0_0.upgradeVaults.selector;
        selectors[1] = UUPSUpgradeable.upgradeToAndCall.selector;
        protocolAccessManager.setTargetFunctionRole(address(royaltyPolicyLAP), selectors, ProtocolAdmin.UPGRADER_ROLE);

        // Pause
        selectors = new bytes4[](2);
        selectors[0] = ProtocolPausableUpgradeable.pause.selector;
        selectors[1] = ProtocolPausableUpgradeable.unpause.selector;

        protocolAccessManager.labelRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, ProtocolAdmin.PAUSE_ADMIN_ROLE_LABEL);
        protocolAccessManager.setTargetFunctionRole(
            address(accessController),
            selectors,
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
        protocolAccessManager.setTargetFunctionRole(address(disputeModule), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(
            address(licensingModule),
            selectors,
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
        protocolAccessManager.setTargetFunctionRole(address(royaltyModule), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        protocolAccessManager.setTargetFunctionRole(
            address(royaltyPolicyLAP),
            selectors,
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
        protocolAccessManager.setTargetFunctionRole(
            address(ipAssetRegistry),
            selectors,
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
        protocolAccessManager.setTargetFunctionRole(
            address(licenseRegistry),
            selectors,
            ProtocolAdmin.PAUSE_ADMIN_ROLE
        );
        protocolAccessManager.setTargetFunctionRole(address(protocolPauser), selectors, ProtocolAdmin.PAUSE_ADMIN_ROLE);
        ///////// Role Granting /////////
        protocolAccessManager.grantRole(ProtocolAdmin.UPGRADER_ROLE, multisig, upgraderExecDelay);
        protocolAccessManager.grantRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, multisig, 0);
        protocolAccessManager.grantRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, address(protocolPauser), 0);
        protocolAccessManager.grantRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, multisig, 0);

        ///////// Renounce admin role /////////
        protocolAccessManager.renounceRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, deployer);
    }

    /// @dev Get the deterministic deployed address of a contract with CREATE3
    function _getDeployedAddress(string memory name) private view returns (address) {
        return create3Deployer.getDeployed(_getSalt(name));
    }

    /// @dev Load the implementation address from the proxy contract
    function _loadProxyImpl(address proxy) private view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }
}
