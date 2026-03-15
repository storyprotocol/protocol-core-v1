// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ProtocolPausableUpgradeable } from "../../../contracts/pause/ProtocolPausableUpgradeable.sol";

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

contract Pause is Script {
    // Mainnet addresses
    address constant ACCESS_CONTROLLER = 0xcCF37d0a503Ee1D4C11208672e622ed3DFB2275a;
    address constant DISPUTE_MODULE = 0x9b7A9c70AFF961C799110954fc06F3093aeb94C5;
    address constant ARBITRATION_POLICY_UMA = 0xfFD98c3877B8789124f02C7E8239A4b0Ef11E936;
    address constant EVEN_SPLIT_GROUP_POOL = 0xf96f2c30b41Cb6e0290de43C8528ae83d4f33F89;
    address constant GROUPING_MODULE = 0x69D3a7aa9edb72Bc226E745A7cCdd50D947b69Ac;
    address constant LICENSING_MODULE = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    address constant ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
    address constant ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    address constant ROYALTY_POLICY_LRP = 0x9156e603C949481883B1d3355c6f1132D191fC41;
    address constant IP_ASSET_REGISTRY = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
    // TODO: add staking contract

    // Run with Ledger HW wallet: forge script script/foundry/pause/pause.s.sol --rpc-url https://mainnet.storyrpc.io/ --ledger --broadcast
    // Run with Trezor HW wallet: forge script script/foundry/pause/pause.s.sol --rpc-url https://mainnet.storyrpc.io/ --trezor --broadcast
    function run() public {
        console2.log("Initiate pausing");
        vm.startBroadcast();

        address[] memory contractsToPause = getPausableContracts();
        for (uint256 i = 0; i < contractsToPause.length; i++) {
            ProtocolPausableUpgradeable(contractsToPause[i]).pause();
        }

        vm.stopBroadcast();
    }

    function getPausableContracts() public view returns (address[] memory) {
        address[] memory contracts = new address[](10);
        contracts[0] = ACCESS_CONTROLLER;
        contracts[1] = DISPUTE_MODULE;
        contracts[2] = ARBITRATION_POLICY_UMA;
        contracts[3] = EVEN_SPLIT_GROUP_POOL;
        contracts[4] = GROUPING_MODULE;
        contracts[5] = LICENSING_MODULE;
        contracts[6] = ROYALTY_MODULE;
        contracts[7] = ROYALTY_POLICY_LAP;
        contracts[8] = ROYALTY_POLICY_LRP;
        contracts[9] = IP_ASSET_REGISTRY;
        return contracts;
    }
}