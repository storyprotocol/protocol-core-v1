/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";

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
import { ImplDeployerV1_1_0 } from "./v1-1-0_impl-deployer.sol";
import { JsonDeploymentHandler } from "../../utils/JsonDeploymentHandler.s.sol";
import { StringUtil } from "../../utils/StringUtil.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";

contract DeployImplRunnerV1_1_0 is Script, BroadcastManager, JsonDeploymentHandler, ImplDeployerV1_1_0 {

    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 internal CREATE3_DEFAULT_SEED = 0;
    // PROXY 1967 IMPLEMENTATION STORAGE SLOTS
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    ICreate3Deployer internal immutable create3Deployer;

    string constant VERSION = "1.1.0";

    // License system
    LicenseToken internal licenseToken;
    LicensingModule internal licensingModule;
    DisputeModule internal disputeModule;
    ModuleRegistry internal moduleRegistry;
    AccessController internal accessController;
    RoyaltyModule internal royaltyModule;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    LicenseRegistry internal licenseRegistry;
    PILicenseTemplate internal pilTemplate;
    IPAccountImpl internal ipAccountImpl;
    IPAssetRegistry internal ipAssetRegistry;

    constructor() JsonDeploymentHandler("main") ImplDeployerV1_1_0() {
        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
    }

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public virtual {
        // _validate(); // StorageLayoutChecker.s.sol
        _readDeployment(); // JsonDeploymentHandler.s.sol
        // Load existing contracts
        licensingModule = LicensingModule(_readAddress("LicensingModule"));
        licenseToken = LicenseToken(_readAddress("LicenseToken"));
        licenseRegistry = LicenseRegistry(_readAddress("LicenseRegistry"));
        pilTemplate = PILicenseTemplate(_readAddress("PILicenseTemplate"));
        ipAssetRegistry = IPAssetRegistry(_readAddress("IPAssetRegistry"));
        accessController = AccessController(_readAddress("AccessController"));
        royaltyModule = RoyaltyModule(_readAddress("RoyaltyModule"));
        royaltyPolicyLAP = RoyaltyPolicyLAP(_readAddress("RoyaltyPolicyLAP"));

        disputeModule = DisputeModule(_readAddress("DisputeModule"));
        moduleRegistry = ModuleRegistry(_readAddress("ModuleRegistry"));

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

        _beginBroadcast(); // BroadcastManager.s.sol

        
        UpgradeProposal[] memory proposals = deploy(CREATE3_DEFAULT_SEED, ERC6551_REGISTRY, proxies, dependencies);

        _writeUpgradeProposals(VERSION, proposals); // JsonDeploymentHandler.s.sol
        _endBroadcast(); // BroadcastManager.s.sol
    }

    /// @dev Load the implementation address from the proxy contract
    function _loadProxyImpl(address proxy) private view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

}
