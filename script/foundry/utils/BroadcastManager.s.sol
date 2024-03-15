// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";

import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";
import { DeployEnv } from "../../../script/foundry/deployment/DeployEnv.sol";

contract BroadcastManager is Script {

    function _beginBroadcast() internal returns (DeployEnv memory env) {
        uint256 deployerPrivateKey;
        if (block.chainid == 1) { // Tenderly mainnet fork
            deployerPrivateKey = vm.envUint("MAINNET_PRIVATEKEY");
            
            vm.startBroadcast(deployerPrivateKey);
            return env;
        } else if (block.chainid == 11155111) {
            deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATEKEY");
            env = DeployEnv({
                deployer: vm.envAddress("SEPOLIA_DEPLOYER_ADDRESS"),
                multisig: vm.envAddress("SEPOLIA_MULTISIG_ADDRESS"),
                roleGrantDelay: 0, // TODO: define prod delay
                roleExecDelay: 0 // TODO: define prod delay
            });
            vm.startBroadcast(deployerPrivateKey);
            return env;
        } else if (block.chainid == 31337) {
            env = DeployEnv({
                deployer: address(0x456),
                multisig: address(0x999),
                roleGrantDelay: 0, // TODO: define prod delay
                roleExecDelay: 0 // TODO: define prod delay
            });
            vm.startPrank(env.deployer);
            return env;
        } else {
            revert("Unsupported chain");
        }
    }

    function _endBroadcast() internal {
        if (block.chainid == 31337) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
