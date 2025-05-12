/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/console2.sol";
import { TxGenerator } from "../utils/upgrades/TxGenerator.s.sol";

/**
 * @title UpgradeTxGenerator
 * @dev Script for scheduling, executing, or canceling upgrades for a set of contracts
 *
 *      To use run the script with the following command:
 *      forge script script/foundry/upgrades/UpgradeTxGenerator.example.s.sol:UpgradeTxGeneratorExample --rpc-url=$RPC_URL --broadcast --priority-gas-price=1 --legacy --private-key=$PRIVATEKEY --skip-simulation
 */
contract UpgradeTxGeneratorExample is TxGenerator {
    constructor() TxGenerator(
        "vx.x.x", // From version (e.g. v1.2.3)
        "vx.x.x" // To version (e.g. v1.3.2)
    ) {}

    function _generateActions() internal virtual override {
        console2.log("Generating schedule, execute, and cancel txs  -------------");
        _generateAction("ModuleRegistry");
        _generateAction("IPAssetRegistry");
        _generateAction("AccessController");
        _generateAction("LicenseRegistry");
        _generateAction("DisputeModule");
        _generateAction("RoyaltyModule");
        _generateAction("GroupNFT");
        _generateAction("GroupingModule");
        _generateAction("LicensingModule");
        _generateAction("LicenseToken");
        _generateAction("RoyaltyPolicyLAP");
        _generateAction("RoyaltyPolicyLRP");
        _generateAction("CoreMetadataModule");
        _generateAction("PILicenseTemplate");
        _generateAction("IpRoyaltyVault");
        _generateAction("EvenSplitGroupPool");
        _generateAction("ArbitrationPolicyUMA");
        _generateAction("ProtocolPauseAdmin");
        _generateAction("IPAccountImplCode");
    }
}
