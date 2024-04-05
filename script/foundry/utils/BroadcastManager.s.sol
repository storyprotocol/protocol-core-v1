// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";

import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";

contract BroadcastManager is Script {
    address public multisig;
    address public deployer;

    function _beginBroadcast() internal {
        uint256 deployerPrivateKey;
        if (block.chainid == 1) { // Tenderly mainnet fork
            deployerPrivateKey = vm.envUint("MAINNET_PRIVATEKEY");
            deployer = vm.envAddress("MAINNET_DEPLOYER_ADDRESS");
            multisig = vm.envAddress("MAINNET_MULTISIG_ADDRESS");
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == 11155111) {
            deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATEKEY");
            deployer = vm.envAddress("SEPOLIA_DEPLOYER_ADDRESS");
            multisig = vm.envAddress("SEPOLIA_MULTISIG_ADDRESS");
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == 31337) {
            require(deployer != address(0), "Deployer not set");
            vm.startPrank(deployer);
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
