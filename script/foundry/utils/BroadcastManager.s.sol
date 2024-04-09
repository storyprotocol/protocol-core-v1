// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";

import { StringUtil } from "./StringUtil.sol";
import { MockERC20 } from "../../../test/foundry/mocks/token/MockERC20.sol";

contract BroadcastManager is Script {
    address public multisig;
    address public deployer;

    function _beginBroadcast() internal {
        uint256 deployerPrivateKey;
        if (block.chainid == 1) { // Tenderly mainnet fork
            deployerPrivateKey = vm.envUint("MAINNET_PRIVATEKEY");
            deployer = vm.addr(deployerPrivateKey);
            multisig = vm.envAddress("MAINNET_MULTISIG_ADDRESS");
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == 11155111) {
            deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATEKEY");
            deployer = vm.addr(deployerPrivateKey);
            multisig = vm.envAddress("SEPOLIA_MULTISIG_ADDRESS");
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == 31337) {
            require(deployer != address(0), "Deployer not set");
            multisig = vm.addr(0x987321);
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
