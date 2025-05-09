/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/console2.sol";
import { TxGenerator } from "../utils/upgrades/TxGenerator.s.sol";

/**
 * @title UpgradeExecutor
 * @dev Script for scheduling, executing, or canceling upgrades for a set of contracts
 *
 *      To use run the script with the following command:
 *      forge script script/foundry/upgrades/UpgradeExecutor.example.s.sol:UpgradeExecutorExample --rpc-url=$RPC_URL --broadcast --priority-gas-price=1 --legacy --private-key=$PRIVATEKEY --skip-simulation
 */
contract UpgradeExecutorExample is TxGenerator {
    constructor() TxGenerator(
        "v1.3.1", // From version (e.g. v1.2.3)
        "v1.3.2" // To version (e.g. v1.3.2)
    ) {}

    /**
     * @dev Generates schedule upgrade txs for a set of contracts
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to upgrade. For example, if upgrading only IPAssetRegistry and GroupingModule,
     * keep just those two _scheduleUpgrade() calls and remove the rest.
     */
    function _generateScheduleTxs() internal virtual override {
        console2.log("Scheduling upgrades  -------------");
        _generateScheduleTx("ModuleRegistry");
        _generateScheduleTx("IPAssetRegistry");
        _generateScheduleTx("AccessController");
        _generateScheduleTx("LicenseRegistry");
        _generateScheduleTx("DisputeModule");
        _generateScheduleTx("RoyaltyModule");
        _generateScheduleTx("GroupNFT");
        _generateScheduleTx("GroupingModule");
        _generateScheduleTx("LicensingModule");
        _generateScheduleTx("LicenseToken");
        _generateScheduleTx("RoyaltyPolicyLAP");
        _generateScheduleTx("RoyaltyPolicyLRP");
        _generateScheduleTx("CoreMetadataModule");
        _generateScheduleTx("PILicenseTemplate");
        _generateScheduleTx("IpRoyaltyVault");
        _generateScheduleTx("EvenSplitGroupPool");
        _generateScheduleTx("ArbitrationPolicyUMA");
        _generateScheduleTx("ProtocolPauseAdmin");
        _generateScheduleTx("IPAccountImplCode");
    }

    /**
     * @dev Generates execute upgrade txs for a set of contracts
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to upgrade. For example, if upgrading only IPAssetRegistry and GroupingModule,
     * keep just those two _executeUpgrade() calls and remove the rest.
     */
    function _generateExecuteTxs() internal virtual override {
        console2.log("Executing upgrades  -------------");
        _generateExecuteTx("ModuleRegistry");
        _generateExecuteTx("IPAssetRegistry");
        _generateExecuteTx("AccessController");
        _generateExecuteTx("LicenseRegistry");
        _generateExecuteTx("DisputeModule");
        _generateExecuteTx("RoyaltyModule");
        _generateExecuteTx("GroupNFT");
        _generateExecuteTx("GroupingModule");
        _generateExecuteTx("LicensingModule");
        _generateExecuteTx("LicenseToken");
        _generateExecuteTx("RoyaltyPolicyLAP");
        _generateExecuteTx("RoyaltyPolicyLRP");
        _generateExecuteTx("CoreMetadataModule");
        _generateExecuteTx("PILicenseTemplate");
        _generateExecuteTx("IpRoyaltyVault");
        _generateExecuteTx("EvenSplitGroupPool");
        _generateExecuteTx("ArbitrationPolicyUMA");
        _generateExecuteTx("ProtocolPauseAdmin");
        _generateExecuteTx("IPAccountImplCode");
    }


    /**
     * @dev Generates cancel scheduled upgrade txs for a set of contracts
     * This is a template listing all upgradeable contracts. Remove any contracts you don't
     * want to cancel. For example, if canceling only IPAssetRegistry and GroupingModule,
     * keep just those two _cancelScheduledUpgrade() calls and remove the rest.
     */
    function _generateCancelTxs() internal virtual override {
        console2.log("Cancelling upgrades  -------------");
        _generateCancelTx("ModuleRegistry");
        _generateCancelTx("IPAssetRegistry");
        _generateCancelTx("AccessController");
        _generateCancelTx("LicenseRegistry");
        _generateCancelTx("DisputeModule");
        _generateCancelTx("RoyaltyModule");
        _generateCancelTx("GroupNFT");
        _generateCancelTx("GroupingModule");
        _generateCancelTx("LicensingModule");
        _generateCancelTx("LicenseToken");
        _generateCancelTx("RoyaltyPolicyLAP");
        _generateCancelTx("RoyaltyPolicyLRP");
        _generateCancelTx("CoreMetadataModule");
        _generateCancelTx("PILicenseTemplate");
        _generateCancelTx("IpRoyaltyVault");
        _generateCancelTx("EvenSplitGroupPool");
        _generateCancelTx("ArbitrationPolicyUMA");
        _generateCancelTx("ProtocolPauseAdmin");
        _generateCancelTx("IPAccountImplCode");
    }
}
