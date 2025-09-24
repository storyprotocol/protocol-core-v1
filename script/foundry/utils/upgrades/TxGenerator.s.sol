/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

// contracts
import { ProtocolAdmin } from "../../../../contracts/lib/ProtocolAdmin.sol";
import { IIPAssetRegistry } from "../../../../contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IVaultController } from "../../../../contracts/interfaces/modules/royalty/policies/IVaultController.sol";

// script
import { JsonDeploymentHandler } from "../JsonDeploymentHandler.s.sol";
import { JsonBatchTxHelper } from "../JsonBatchTxHelper.s.sol";
import { StringUtil } from "../StringUtil.sol";
import { ICreate3Deployer } from "../ICreate3Deployer.sol";
import { UpgradedImplHelper } from "./UpgradedImplHelper.sol";
import { StorageLayoutChecker } from "./StorageLayoutCheck.s.sol";

/**
 * @title TxGenerator
 * @notice Script to generate schedule, execute, or cancel txs for a set of contracts
 * @dev This script will read a deployment file and upgrade proposals file to generate schedule, execute, or cancel txs
 */
abstract contract TxGenerator is Script, JsonDeploymentHandler, JsonBatchTxHelper {
    address internal CREATE3_DEPLOYER = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;

    ICreate3Deployer internal immutable create3Deployer;
    AccessManager internal accessManager;

    /// @notice The version to upgrade from
    string fromVersion;
    /// @notice The version to upgrade to
    string toVersion;
    /// @notice The deployer address
    address public deployer;

    /// @dev check if the caller has the Upgrader role
    modifier onlyUpgraderRole() {
        (bool isMember, ) = accessManager.hasRole(ProtocolAdmin.UPGRADER_ROLE, deployer);
        require(isMember, "Caller must have Upgrader role");
        _;
    }

    ///@dev Constructor
    ///@param _fromVersion The version to upgrade from
    ///@param _toVersion The version to upgrade to
    constructor(
        string memory _fromVersion,
        string memory _toVersion
    ) JsonDeploymentHandler("main") JsonBatchTxHelper() {
        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
        fromVersion = _fromVersion;
        toVersion = _toVersion;
    }

    function run() public virtual {
        // Read deployment file for proxy addresses
        _readDeployment(fromVersion); // JsonDeploymentHandler.s.sol
        // Load AccessManager
        accessManager = AccessManager(_readAddress("ProtocolAccessManager"));
        console2.log("accessManager", address(accessManager));
        // Read upgrade proposals file
        _readProposalFile(fromVersion, toVersion); // JsonDeploymentHandler.s.sol

        uint256 deployerPrivateKey = vm.envUint("STORY_PRIVATEKEY");
        deployer = vm.addr(deployerPrivateKey);
        
        _generateActions();

        _writeBatchTxsOutput(string.concat("schedule", "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
        _writeBatchTxsOutput(string.concat("execute", "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
        _writeBatchTxsOutput(string.concat("cancel", "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol 
    }

    function _generateActions() internal virtual;

    function _generateAction(string memory key) internal {
        _generateScheduleTx(key);
        _generateExecuteTx(key);
        _generateCancelTx(key);
    }

    function _generateScheduleTx(string memory key) internal {
        console2.log("--------------------");
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal(key);
        console2.log("Scheduling", key);
        console2.log("Proxy", p.proxy);
        console2.log("New Impl", p.newImpl);
        
        //_checkMatchingAccessManager(key, p.proxy);
        bytes memory data = _getExecutionData(key, p);
        if (data.length == 0) revert("No data to schedule");

        _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.schedule, (p.proxy, data, 0)));
        
        console2.log("--------------------");
    }

    function _generateExecuteTx(string memory key) internal {
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal(key);

        console2.log("Upgrading", key);
        console2.log("Proxy", p.proxy);
        console2.log("New Impl", p.newImpl);
        
        //_checkMatchingAccessManager(key, p.proxy);
        bytes memory data = _getExecutionData(key, p);
        uint48 schedule = accessManager.getSchedule(accessManager.hashOperation(deployer, p.proxy, data));
        
        console2.log("schedule", schedule);
        console2.log("Execute scheduled tx");
        console2.logBytes(data);

        _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.execute, (p.proxy, data)));
    }

    function _generateCancelTx(string memory key) internal {
        console2.log("--------------------");
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal(key);
        console2.log("Scheduling", key);
        console2.log("Proxy", p.proxy);
        console2.log("New Impl", p.newImpl);
        
        //_checkMatchingAccessManager(key, p.proxy);
        bytes memory data = _getExecutionData(key, p);
        if (data.length == 0) revert("No data to schedule");

        _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.cancel, (deployer, p.proxy, data)));

        console2.log("--------------------");
    }

    function _getExecutionData(
        string memory key,
        UpgradedImplHelper.UpgradeProposal memory p
    ) internal virtual returns (bytes memory data) {
        if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("IpRoyaltyVault"))) {
            console2.log("encoding upgradeVaults");
            data = abi.encodeCall(IVaultController.upgradeVaults, (p.newImpl));
        } else if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("IPAccountImplCode"))) {
            console2.log("encoding upgradeIPAccount");
            data = abi.encodeCall(IIPAssetRegistry.upgradeIPAccountImpl, (p.newImpl));
        } else {
            console2.log("encoding upgradeUUPS");
            data = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (p.newImpl, ""));
        }
        return data;
    }

    function _checkMatchingAccessManager(string memory contractKey, address proxy) virtual internal {
        if (keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("IpRoyaltyVault")) &&
            keccak256(abi.encodePacked(contractKey)) != keccak256(abi.encodePacked("IPAccountImplCode"))) {
            require(
                AccessManaged(proxy).authority() == address(accessManager),
                "Proxy's Authority must equal accessManager"
            );
        }
    }
}
