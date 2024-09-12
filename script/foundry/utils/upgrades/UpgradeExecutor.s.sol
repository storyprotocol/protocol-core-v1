/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { AccessController } from "contracts/access/AccessController.sol";
import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";

import { IVaultController } from "contracts/interfaces/modules/royalty/policies/IVaultController.sol";

// script
import { BroadcastManager } from "../BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../JsonDeploymentHandler.s.sol";
import { JsonBatchTxHelper } from "../JsonBatchTxHelper.s.sol";
import { StringUtil } from "../StringUtil.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";
import { UpgradedImplHelper } from "./UpgradedImplHelper.sol";
import { StorageLayoutChecker } from "./StorageLayoutCheck.s.sol";

/**
 * @title UpgradeExecutor
 * @notice Script to schedule, execute, or cancel upgrades for a set of contracts
 * @dev This script will read a deployment file and upgrade proposals file to schedule, execute, or cancel upgrades
 */
abstract contract UpgradeExecutor is Script, BroadcastManager, JsonDeploymentHandler, JsonBatchTxHelper {
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 internal CREATE3_DEFAULT_SEED = 0;

    /// @notice Upgrade modes
    enum UpgradeModes {
        SCHEDULE, // Schedule upgrades in AccessManager
        EXECUTE, // Execute scheduled upgrades
        CANCEL // Cancel scheduled upgrades
    }
    /// @notice End result of the script
    enum Output {
        TX_EXECUTION, // One Tx per operation
        BATCH_TX_EXECUTION, // Use AccessManager to batch actions in 1 tx through (multicall)
        BATCH_TX_JSON // Prepare raw bytes for multisig. Multisig may batch txs (e.g. Gnosis Safe JSON input in tx builder)
    }

    ///////// USER INPUT /////////
    UpgradeModes mode;
    Output outputType;

    /////////////////////////////
    ICreate3Deployer internal immutable create3Deployer;
    AccessManager internal accessManager;

    /// @notice The version to upgrade from
    string fromVersion;
    /// @notice The version to upgrade to
    string toVersion;
    /// @notice action acumulator for batch txs
    bytes[] multicallData;

    /// @dev check if the proxy's authority is the accessManager in the file
    /// @param proxy The proxy address
    modifier onlyMatchingAccessManager(address proxy) {
        require(
            AccessManaged(proxy).authority() == address(accessManager),
            "Proxy's Authority must equal accessManager"
        );
        _;
    }

    /// @dev check if the caller has the Upgrader role
    modifier onlyUpgraderRole() {
        (bool isMember, ) = accessManager.hasRole(ProtocolAdmin.UPGRADER_ROLE, deployer);
        require(isMember, "Caller must have Upgrader role");
        _;
    }

    ///@dev Constructor
    ///@param _fromVersion The version to upgrade from
    ///@param _toVersion The version to upgrade to
    ///@param _mode The upgrade mode
    ///@param _outputType The output type
    constructor(
        string memory _fromVersion,
        string memory _toVersion,
        UpgradeModes _mode,
        Output _outputType
    ) JsonDeploymentHandler("main") JsonBatchTxHelper() {
        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
        fromVersion = _fromVersion;
        toVersion = _toVersion;
        mode = _mode;
        outputType = _outputType;
    }

    function run() public virtual {
        // Read deployment file for proxy addresses
        _readDeployment(fromVersion); // JsonDeploymentHandler.s.sol
        // Load AccessManager
        accessManager = AccessManager(_readAddress("ProtocolAccessManager"));
        console2.log("accessManager", address(accessManager));
        // Read upgrade proposals file
        _readProposalFile(fromVersion, toVersion); // JsonDeploymentHandler.s.sol
        _beginBroadcast(); // BroadcastManager.s.sol
        if (outputType == Output.BATCH_TX_JSON) {
            console2.log(multisig);
            deployer = multisig;
            console2.log("Generating tx json...");
        }
        // Decide actions based on mode
        if (mode == UpgradeModes.SCHEDULE) {
            _scheduleUpgrades();
        } else if (mode == UpgradeModes.EXECUTE) {
            _executeUpgrades();
        } else if (mode == UpgradeModes.CANCEL) {
            _cancelScheduledUpgrades();
        } else {
            revert("Invalid mode");
        }
        // If output is JSON, write the batch txx to file
        if (outputType == Output.BATCH_TX_JSON) {
            string memory action;
            if (mode == UpgradeModes.SCHEDULE) {
                action = "schedule";
            } else if (mode == UpgradeModes.EXECUTE) {
                action = "execute";
            } else if (mode == UpgradeModes.CANCEL) {
                action = "cancel";
            } else {
                revert("Invalid mode");
            }
            _writeBatchTxsOutput(string.concat(action, "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
        } else if (outputType == Output.BATCH_TX_EXECUTION) {
            // If output is BATCH_TX_EXECUTION, execute the batch txs
            _executeBatchTxs();
        }
        // If output is TX_EXECUTION, no further action is needed
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _scheduleUpgrades() internal virtual;

    function _scheduleUpgrade(string memory key) internal {
        console2.log("--------------------");
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal(key);
        console2.log("Scheduling", key);
        console2.log("Proxy", p.proxy);
        console2.log("New Impl", p.newImpl);
        _scheduleUpgrade(key, p);
        console2.log("--------------------");
    }

    function _scheduleUpgrade(
        string memory key,
        UpgradedImplHelper.UpgradeProposal memory p
    ) private onlyMatchingAccessManager(p.proxy) onlyUpgraderRole {
        bytes memory data = _getExecutionData(key, p);
        if (data.length == 0) {
            revert("No data to schedule");
        }
        if (outputType == Output.TX_EXECUTION) {
            console2.log("Schedule tx execution");
            console2.logBytes(data);

            (bytes32 operationId, uint32 nonce) = accessManager.schedule(
                p.proxy, // target
                data,
                0 // when
            );
            console2.log("Scheduled", nonce);
            console2.log("OperationId");
            console2.logBytes32(operationId);
        } else if (outputType == Output.BATCH_TX_EXECUTION) {
            console2.log("Adding tx to batch");
            multicallData.push(abi.encodeCall(AccessManager.schedule, (p.proxy, data, 0)));
            console2.logBytes(multicallData[multicallData.length - 1]);
        } else if (outputType == Output.BATCH_TX_JSON) {
            console2.log("------------ WARNING: NOT TESTED ------------");
            _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.execute, (p.proxy, data)));
        } else {
            revert("Unsupported mode");
        }
    }

    function _executeUpgrades() internal virtual;

    function _executeUpgrade(string memory key) internal {
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal(key);

        console2.log("Upgrading", key);
        console2.log("Proxy", p.proxy);
        console2.log("New Impl", p.newImpl);
        _executeUpgrade(key, p);
    }

    function _executeUpgrade(
        string memory key,
        UpgradedImplHelper.UpgradeProposal memory p
    ) private onlyMatchingAccessManager(p.proxy) {
        bytes memory data = _getExecutionData(key, p);
        uint48 schedule = accessManager.getSchedule(accessManager.hashOperation(deployer, p.proxy, data));
        console2.log("schedule", schedule);
        console2.log("Execute scheduled tx");
        console2.logBytes(data);

        if (outputType == Output.TX_EXECUTION) {
            console2.log("Execute upgrade tx");
            // We don't currently support reinitializer calls
            accessManager.execute(p.proxy, data);
        } else if (outputType == Output.BATCH_TX_EXECUTION) {
            console2.log("Adding execution tx to batch");
            multicallData.push(abi.encodeCall(AccessManager.execute, (p.proxy, data)));
            console2.logBytes(multicallData[multicallData.length - 1]);
        } else if (outputType == Output.BATCH_TX_JSON) {
            _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.execute, (p.proxy, data)));
        } else {
            revert("Invalid output type");
        }
    }

    function _cancelScheduledUpgrades() internal virtual;

    function _cancelScheduledUpgrade(string memory key) internal {
        console2.log("--------------------");
        UpgradedImplHelper.UpgradeProposal memory p = _readUpgradeProposal(key);
        console2.log("Scheduling", key);
        console2.log("Proxy", p.proxy);
        console2.log("New Impl", p.newImpl);
        _cancelScheduledUpgrade(key, p);
        console2.log("--------------------");
    }

    function _cancelScheduledUpgrade(
        string memory key,
        UpgradedImplHelper.UpgradeProposal memory p
    ) private onlyMatchingAccessManager(p.proxy) {
        bytes memory data = _getExecutionData(key, p);
        if (data.length == 0) {
            revert("No data to schedule");
        }
        if (outputType == Output.TX_EXECUTION) {
            console2.log("Execute cancelation");
            console2.logBytes(data);
            uint32 nonce = accessManager.cancel(deployer, p.proxy, data);
            console2.log("Cancelled", nonce);
        } else if (outputType == Output.BATCH_TX_EXECUTION) {
            console2.log("Adding cancel tx to batch");
            multicallData.push(abi.encodeCall(AccessManager.cancel, (deployer, p.proxy, data)));
            console2.logBytes(multicallData[multicallData.length - 1]);
        } else if (outputType == Output.BATCH_TX_JSON) {
            console2.log("------------ WARNING: NOT TESTED ------------");
            _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.cancel, (deployer, p.proxy, data)));
        } else {
            revert("Unsupported mode");
        }
    }

    function _executeBatchTxs() internal {
        console2.log("Executing batch txs...");
        console2.log("Access Manager", address(accessManager));
        bytes[] memory results = accessManager.multicall(multicallData);
        console2.log("Results");
        for (uint256 i = 0; i < results.length; i++) {
            console2.log(i, ": ");
            console2.logBytes(results[i]);
        }
    }

    function _getExecutionData(
        string memory key,
        UpgradedImplHelper.UpgradeProposal memory p
    ) internal returns (bytes memory data) {
        if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("IpRoyaltyVault"))) {
            console2.log("encoding upgradeVaults");
            data = abi.encodeCall(IVaultController.upgradeVaults, (p.newImpl));
        } else {
            console2.log("encoding upgradeUUPS");
            data = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (p.newImpl, ""));
        }
        return data;
    }
}
