/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { UpgradeExecutor } from "../utils/upgrades/UpgradeExecutor.s.sol";

/**
 * @title UpgradeExecutor
 * @dev Script for scheduling, executing, or canceling upgrades for a set of contracts
 *
 *      To use run the script with the following command:
 *      forge script script/foundry/upgrades/UpgradeExecutor.example.s.sol:UpgradeExecutorExample --rpc-url=$RPC_URL --broadcast --priority-gas-price=1 --legacy --private-key=$PRIVATEKEY --skip-simulation
 */
contract UpgradeExecutorExample is UpgradeExecutor {
    constructor() UpgradeExecutor(
        "vx.x.x", // From version (e.g. v1.2.3)
        "vx.x.x", // To version (e.g. v1.3.2)
        UpgradeModes.EXECUTE, // Schedule, Cancel or Execute upgrade
        Output.BATCH_TX_EXECUTION // Output mode
    ) {}

    /**
     * @dev Schedules upgrades for a set of contracts, only called when UpgradeModes.SCHEDULE is used
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to upgrade. For example, if upgrading only IPAssetRegistry and GroupingModule,
     * keep just those two _scheduleUpgrade() calls and remove the rest.
     */
    function _scheduleUpgrades() internal virtual override {
        console2.log("Scheduling upgrades  -------------");
        _scheduleUpgrade("ModuleRegistry");
        _scheduleUpgrade("IPAssetRegistry");
        _scheduleUpgrade("AccessController");
        _scheduleUpgrade("LicenseRegistry");
        _scheduleUpgrade("DisputeModule");
        _scheduleUpgrade("RoyaltyModule");
        _scheduleUpgrade("GroupNFT");
        _scheduleUpgrade("GroupingModule");
        _scheduleUpgrade("LicensingModule");
        _scheduleUpgrade("LicenseToken");
        _scheduleUpgrade("RoyaltyPolicyLAP");
        _scheduleUpgrade("RoyaltyPolicyLRP");
        _scheduleUpgrade("CoreMetadataModule");
        _scheduleUpgrade("PILicenseTemplate");
        _scheduleUpgrade("IpRoyaltyVault");
        _scheduleUpgrade("EvenSplitGroupPool");
        _scheduleUpgrade("ArbitrationPolicyUMA");
        _scheduleUpgrade("ProtocolPauseAdmin");
        _scheduleUpgrade("IPAccountImplCode");
    }

    /**
     * @dev Executes upgrades for a set of contracts, only called when UpgradeModes.EXECUTE is used
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to upgrade. For example, if upgrading only IPAssetRegistry and GroupingModule,
     * keep just those two _executeUpgrade() calls and remove the rest.
     */
    function _executeUpgrades() internal virtual override {
        console2.log("Executing upgrades  -------------");
        _executeUpgrade("ModuleRegistry");
        _executeUpgrade("IPAssetRegistry");
        _executeUpgrade("AccessController");
        _executeUpgrade("LicenseRegistry");
        _executeUpgrade("DisputeModule");
        _executeUpgrade("RoyaltyModule");
        _executeUpgrade("GroupNFT");
        _executeUpgrade("GroupingModule");
        _executeUpgrade("LicensingModule");
        _executeUpgrade("LicenseToken");
        _executeUpgrade("RoyaltyPolicyLAP");
        _executeUpgrade("RoyaltyPolicyLRP");
        _executeUpgrade("CoreMetadataModule");
        _executeUpgrade("PILicenseTemplate");
        _executeUpgrade("IpRoyaltyVault");
        _executeUpgrade("EvenSplitGroupPool");
        _executeUpgrade("ArbitrationPolicyUMA");
        _executeUpgrade("ProtocolPauseAdmin");
        _executeUpgrade("IPAccountImplCode");
    }


    /**
     * @dev Cancels scheduled upgrades for a set of contracts, only called when UpgradeModes.CANCEL is used
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to cancel. For example, if canceling only IPAssetRegistry and GroupingModule,
     * keep just those two _cancelScheduledUpgrade() calls and remove the rest.
     */
    function _cancelScheduledUpgrades() internal virtual override {
        console2.log("Cancelling upgrades  -------------");
        _cancelScheduledUpgrade("ModuleRegistry");
        _cancelScheduledUpgrade("IPAssetRegistry");
        _cancelScheduledUpgrade("AccessController");
        _cancelScheduledUpgrade("LicenseRegistry");
        _cancelScheduledUpgrade("DisputeModule");
        _cancelScheduledUpgrade("RoyaltyModule");
        _cancelScheduledUpgrade("GroupNFT");
        _cancelScheduledUpgrade("GroupingModule");
        _cancelScheduledUpgrade("LicensingModule");
        _cancelScheduledUpgrade("LicenseToken");
        _cancelScheduledUpgrade("RoyaltyPolicyLAP");
        _cancelScheduledUpgrade("RoyaltyPolicyLRP");
        _cancelScheduledUpgrade("CoreMetadataModule");
        _cancelScheduledUpgrade("PILicenseTemplate");
        _cancelScheduledUpgrade("IpRoyaltyVault");
        _cancelScheduledUpgrade("EvenSplitGroupPool");
        _cancelScheduledUpgrade("ArbitrationPolicyUMA");
        _cancelScheduledUpgrade("ProtocolPauseAdmin");
        _cancelScheduledUpgrade("IPAccountImplCode");
    }
}
