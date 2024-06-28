/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";

// script
import { BroadcastManager } from "../../utils/BroadcastManager.s.sol";
import { StorageLayoutChecker } from "../../utils/upgrades/StorageLayoutCheck.s.sol";
import { JsonDeploymentHandler } from "../../utils/JsonDeploymentHandler.s.sol";
import { StringUtil } from "../../utils/StringUtil.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";
import { UpgradedImplHelper } from "../../utils/upgrades/UpgradedImplHelper.sol";

contract UpgradeExecV1_1_0 is Script, BroadcastManager, JsonDeploymentHandler {

    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 internal CREATE3_DEFAULT_SEED = 0;
    // PROXY 1967 IMPLEMENTATION STORAGE SLOTS
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    enum UpgradeModes { SCHEDULE, EXECUTE }
    UpgradeModes constant mode = UpgradeModes.EXECUTE;

    ICreate3Deployer internal immutable create3Deployer;


    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    string constant version = "1.1.0";

    constructor() JsonDeploymentHandler("main") {
        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
    }

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public virtual {
        _readProposalFile(version); // JsonDeploymentHandler.s.sol
        _beginBroadcast(); // BroadcastManager.s.sol
        
        _performUpgrade("LicenseToken");
        _performUpgrade("LicensingModule");
        _performUpgrade("LicenseRegistry");
        _performUpgrade("PILicenseTemplate");
        _performUpgrade("AccessController");
        _performUpgrade("RoyaltyModule");
        _performUpgrade("RoyaltyPolicyLAP");
        _performUpgrade("IPAssetRegistry");

        // - IPRoyaltyVaults
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal("IpRoyaltyVault");
        royaltyPolicyLAP = RoyaltyPolicyLAP(p.proxy);
        royaltyPolicyLAP.upgradeVaults(p.newImpl);
        // TODO: Check if the vaults are correctly set

        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _performUpgrade(string memory key) internal {
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal(key);
        console2.log("Upgrading", key);
        console2.log("Proxy", p.proxy);
        console2.log("New Impl", p.newImpl);
        // In this version, we don't have initializer calls. In other versions, we might need to store the bytes in JsonDeploymentHandler
        UUPSUpgradeable(p.proxy).upgradeToAndCall(p.newImpl, "");
        require(_loadProxyImpl(p.proxy) == p.newImpl,  string.concat(key, ": Upgrade failed"));
    }


    /// @dev get the salt for the contract deployment with CREATE3
    function _getSalt(string memory name) private view returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, CREATE3_DEFAULT_SEED));
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
