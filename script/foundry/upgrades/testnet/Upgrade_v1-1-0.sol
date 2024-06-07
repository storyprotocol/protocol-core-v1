/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { AccessController } from "contracts/access/AccessController.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
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
import { PILicenseTemplate, PILTerms } from "contracts/modules/licensing/PILicenseTemplate.sol";
import { LicenseToken } from "contracts/LicenseToken.sol";

// script
import { BroadcastManager } from "../../utils/BroadcastManager.s.sol";
import { StorageLayoutChecker } from "../../utils/upgrades/StorageLayoutCheck.s.sol";
import { JsonDeploymentHandler } from "../../utils/JsonDeploymentHandler.s.sol";
import { StringUtil } from "../../utils/StringUtil.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";

contract UpgradeV1_1_0 is Script, BroadcastManager, JsonDeploymentHandler, StorageLayoutChecker {
    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 internal CREATE3_DEFAULT_SEED = 0;
    // PROXY 1967 IMPLEMENTATION STORAGE SLOTS
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // For arbitration policy
    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 USDC
    // For royalty policy
    uint256 internal constant MAX_ROYALTY_APPROVAL = 10000 ether;
    ICreate3Deployer internal immutable create3Deployer;
    // seed for CREATE3 salt
    uint256 internal create3SaltSeed = CREATE3_DEFAULT_SEED;

    // License system
    LicenseToken internal licenseToken;
    LicensingModule internal licensingModule;
    DisputeModule internal disputeModule;
    ModuleRegistry internal moduleRegistry;
    AccessController internal accessController;
    RoyaltyModule internal royaltyModule;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    LicenseRegistry internal licenseRegistry;
    PILicenseTemplate internal piLicenseTemplate;
    IPAccountImpl internal ipAccountImpl;
    IPAssetRegistry internal ipAssetRegistry;

    constructor() JsonDeploymentHandler("main") {
        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
    }

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public virtual {
        _readDeployment(); // JsonDeploymentHandler.s.sol
        _beginBroadcast(); // BroadcastManager.s.sol
        string memory contractKey;
        address impl;
        address proxy;

        // Load existing contracts
        licensingModule = LicensingModule(_read("LicensingModule"));
        licenseToken = LicenseToken(_read("LicenseToken"));
        licenseRegistry = LicenseRegistry(_read("LicenseRegistry"));
        disputeModule = DisputeModule(_read("DisputeModule"));
        ipAssetRegistry = IPAssetRegistry(_read("IPAssetRegistry"));
        moduleRegistry = ModuleRegistry(_read("ModuleRegistry"));
        accessController = AccessController(_read("AccessController"));
        royaltyModule = RoyaltyModule(_read("RoyaltyModule"));
        piLicenseTemplate = PILicenseTemplate(_read("PILicenseTemplate"));

        // - LicenseToken
        contractKey = "LicenseToken";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(LicenseToken).name, "implementation")),
            abi.encodePacked(
                type(LicenseToken).creationCode,
                abi.encode(address(licensingModule), address(disputeModule))
            )
        );
        // Initializer already called when deploying LicenseToken
        licenseToken.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(licenseToken)) == impl, "LicenseToken Proxy Implementation Mismatch");

        // - LicensingModule
        contractKey = "LicensingModule";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(LicensingModule).name, "implementation")),
            abi.encodePacked(
                type(LicensingModule).creationCode,
                abi.encode(
                    address(accessController),
                    address(ipAssetRegistry),
                    address(moduleRegistry),
                    address(royaltyModule),
                    address(licenseRegistry),
                    address(disputeModule),
                    address(licenseToken)
                )
            )
        );
        licensingModule.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(licensingModule)) == impl, "LicensingModule Proxy Implementation Mismatch");

        // - LicenseRegistry
        contractKey = "LicenseRegistry";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(LicenseRegistry).name, "implementation")),
            abi.encodePacked(
                type(LicenseRegistry).creationCode,
                abi.encode(address(licensingModule), address(disputeModule))
            )
        );
        licenseRegistry.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(licenseRegistry)) == impl, "LicenseRegistry Proxy Implementation Mismatch");

        // - PILicenseTemplate
        contractKey = "PILicenseTemplate";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(PILicenseTemplate).name, "implementation")),
            abi.encodePacked(
                type(PILicenseTemplate).creationCode,
                abi.encode(address(accessController), address(ipAssetRegistry), address(licenseRegistry), address(royaltyModule))
            )
        );
        piLicenseTemplate.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(piLicenseTemplate)) == impl, "PILicenseTemplate Proxy Implementation Mismatch");


        // - AccessController
        contractKey = "AccessController";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(AccessController).name, "implementation")),
            abi.encodePacked(
                type(AccessController).creationCode,
                abi.encode(address(ipAssetRegistry), address(moduleRegistry))
            )
        );
        accessController.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(accessController)) == impl, "AccessController Proxy Implementation Mismatch");

        // - IPAccountImpl
        ipAccountImpl = IPAccountImpl(
            payable (create3Deployer.deploy(
            _getSalt(string.concat(type(IPAccountImpl).name, "implementation")),
            abi.encodePacked(
                type(IPAccountImpl).creationCode,
                address(accessController),
                address(ipAssetRegistry),
                address(licenseRegistry),
                address(moduleRegistry)
            )
         ))
        );

        // - IPAssetRegistry
        contractKey = "IPAssetRegistry";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(IPAssetRegistry).name, "implementation")),
            abi.encodePacked(
                type(IPAssetRegistry).creationCode,
                abi.encode(ERC6551_REGISTRY, address(ipAccountImpl))
            )
        );
        ipAssetRegistry.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(ipAssetRegistry)) == impl, "IPAssetRegistry Proxy Implementation Mismatch");
        
        
        // - RoyaltyModule
        contractKey = "RoyaltyModule";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(RoyaltyModule).name, "implementation")),
            abi.encodePacked(
                type(RoyaltyModule).creationCode,
                abi.encode(address(licensingModule), address(disputeModule), address(licenseRegistry))
            )
        );
        royaltyModule.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(royaltyModule)) == impl, "RoyaltyModule Proxy Implementation Mismatch");

        // - RoyaltyPolicyLAP.sol
        contractKey = "RoyaltyPolicyLAP";
        proxy = _read(contractKey);
        impl = create3Deployer.deploy(
            _getSalt(string.concat(type(RoyaltyPolicyLAP).name, "implementation")),
            abi.encodePacked(
                type(RoyaltyPolicyLAP).creationCode,
                address(royaltyModule), address(licensingModule)
            )
        );
        royaltyPolicyLAP.upgradeToAndCall(impl, "");
        require(_loadProxyImpl(address(royaltyPolicyLAP)) == impl, "RoyaltyPolicyLAP Proxy Implementation Mismatch");

        // - IPRoyaltyVaults
        address ipRoyaltyVaultImpl = 
            create3Deployer.deploy(
                _getSalt(type(IpRoyaltyVault).name),
                abi.encodePacked(
                    type(IpRoyaltyVault).creationCode,
                    abi.encode(address(royaltyPolicyLAP), address(disputeModule))
                )
            );

        royaltyPolicyLAP.upgradeVaults(ipRoyaltyVaultImpl);
        // TODO: Check if the vaults are correctly set
        
        _endBroadcast(); // BroadcastManager.s.sol
    }
    

    function _read(string memory contractKey) private view returns(address) {
        address proxy = _readAddress(contractKey);
        console2.log(string.concat("Upgrading ", contractKey, "..."));
        console2.log("Proxy Address");
        console2.log(proxy);
        return proxy;
    }

    /// @dev get the salt for the contract deployment with CREATE3
    function _getSalt(string memory name) private view returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, create3SaltSeed));
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
