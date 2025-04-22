/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { Multicall } from "@openzeppelin/contracts/utils/Multicall.sol";

// contracts
import { ProtocolAdmin } from "../../../../contracts/lib/ProtocolAdmin.sol";
import { IIPAssetRegistry } from "../../../../contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IVaultController } from "../../../../contracts/interfaces/modules/royalty/policies/IVaultController.sol";

// script
import { BroadcastManager } from "../BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../JsonDeploymentHandler.s.sol";
import { JsonBatchTxHelper } from "../JsonBatchTxHelper.s.sol";
import { StringUtil } from "../StringUtil.sol";
import { ICreate3Deployer } from "../ICreate3Deployer.sol";
import { UpgradedImplHelper } from "./UpgradedImplHelper.sol";
import { StorageLayoutChecker } from "./StorageLayoutCheck.s.sol";

/**
 * @title UpgradeExecutor
 * @notice Script to schedule, execute, or cancel upgrades for a set of contracts
 * @dev This script will read a deployment file and upgrade proposals file to schedule, execute, or cancel upgrades
 */
abstract contract UpgradeExecutor is Script, BroadcastManager, JsonDeploymentHandler, JsonBatchTxHelper {
    address internal CREATE3_DEPLOYER = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;

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
        TX_JSON, // Prepare an array of txs with raw encoded bytes data to be executed by a multisig. MPCVault won't batch with this, Safe would.
        BATCH_TX_JSON // Prepare a tx with AccessManager.multicall() raw encoded bytes data to be executed by a multisig.
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
    /// @notice action accumulator for batch txs
    bytes[] multicallData;

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
        string memory action;
        // Read deployment file for proxy addresses
        _readDeployment(fromVersion); // JsonDeploymentHandler.s.sol
        // Load AccessManager
        accessManager = AccessManager(_readAddress("ProtocolAccessManager"));
        console2.log("accessManager", address(accessManager));
        // Read upgrade proposals file
        _readProposalFile(fromVersion, toVersion); // JsonDeploymentHandler.s.sol
        _beginBroadcast(); // BroadcastManager.s.sol
        if (outputType == Output.TX_JSON) {
            console2.log(multisig);
            deployer = multisig;
            console2.log("Generating tx json...");
        }
        // Decide actions based on mode
        if (mode == UpgradeModes.SCHEDULE) {
            action = "schedule";
            _scheduleUpgrades();
        } else if (mode == UpgradeModes.EXECUTE) {
            action = "execute";
            _executeUpgrades();
        } else if (mode == UpgradeModes.CANCEL) {
            action = "cancel";
            _cancelScheduledUpgrades();
        } else {
            revert("Invalid mode");
        }
        // If output is JSON, write the batch txx to file
        if (outputType == Output.TX_JSON) {
            _writeBatchTxsOutput(string.concat(action, "-", fromVersion, "-to-", toVersion)); // JsonBatchTxHelper.s.sol
        } else if (outputType == Output.BATCH_TX_EXECUTION) {
            // If output is BATCH_TX_EXECUTION, execute the batch txs
            _executeBatchTxs();
        } else if (outputType == Output.BATCH_TX_JSON) {
            _encodeBatchTxs(action);
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
    ) private {
        _checkMatchingAccessManager(key, p.proxy);
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
        } else if (outputType == Output.BATCH_TX_EXECUTION || outputType == Output.BATCH_TX_JSON) {
            console2.log("Adding tx to batch");
            multicallData.push(abi.encodeCall(AccessManager.schedule, (p.proxy, data, 0)));
            console2.logBytes(multicallData[multicallData.length - 1]);
        } else if (outputType == Output.TX_JSON) {
            _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.schedule, (p.proxy, data, 0)), "schedule upgrade");
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
    ) private {
        _checkMatchingAccessManager(key, p.proxy);
        bytes memory data = _getExecutionData(key, p);
        uint48 schedule = accessManager.getSchedule(accessManager.hashOperation(deployer, p.proxy, data));
        console2.log("schedule", schedule);
        console2.log("Execute scheduled tx");
        console2.logBytes(data);

        if (outputType == Output.TX_EXECUTION) {
            console2.log("Execute upgrade tx");
            // We don't currently support reinitializer calls
            accessManager.execute(p.proxy, data);
        } else if (outputType == Output.BATCH_TX_EXECUTION || outputType == Output.BATCH_TX_JSON) {
            console2.log("Adding execution tx to batch");
            multicallData.push(abi.encodeCall(AccessManager.execute, (p.proxy, data)));
            console2.logBytes(multicallData[multicallData.length - 1]);
        } else if (outputType == Output.TX_JSON) {
            _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.execute, (p.proxy, data)), "execute upgrade");
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
    ) private {
        _checkMatchingAccessManager(key, p.proxy);
        bytes memory data = _getExecutionData(key, p);
        if (data.length == 0) {
            revert("No data to schedule");
        }
        if (outputType == Output.TX_EXECUTION) {
            console2.log("Execute cancelation");
            console2.logBytes(data);
            uint32 nonce = accessManager.cancel(deployer, p.proxy, data);
            console2.log("Cancelled", nonce);
        } else if (outputType == Output.BATCH_TX_EXECUTION || outputType == Output.BATCH_TX_JSON) {
            console2.log("Adding cancel tx to batch");
            multicallData.push(abi.encodeCall(AccessManager.cancel, (deployer, p.proxy, data)));
            console2.logBytes(multicallData[multicallData.length - 1]);
        } else if (outputType == Output.TX_JSON) {
            console2.log("------------ WARNING: NOT TESTED ------------");
            _writeTx(address(accessManager), 0, abi.encodeCall(AccessManager.cancel, (deployer, p.proxy, data)), "cancel upgrade");
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

    function _encodeBatchTxs(string memory action) internal {
        bytes memory data = abi.encodeCall(Multicall.multicall, (multicallData));
        console2.log("Encoding batch txs...");
        _writeTx(address(accessManager), 0, data, string(abi.encodePacked("batch ", action, " ", fromVersion, " to ", toVersion)));
        console2.log("Batch txs encoded");
        _writeBatchTxsOutput(string.concat(action, "-", fromVersion, "-to-", toVersion));
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
