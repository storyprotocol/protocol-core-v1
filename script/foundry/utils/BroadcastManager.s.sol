// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";

import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";

contract BroadcastManager is Script {
    address public multisig;
    address public deployer;

    /// @dev USDC addresses are fetched from
    /// (mainnet) https://developers.circle.com/stablecoins/docs/usdc-on-main-networks
    /// (testnet) https://developers.circle.com/stablecoins/docs/usdc-on-test-networks
    function _beginBroadcast() internal {
        uint256 deployerPrivateKey;
        if (block.chainid == 1) { // Tenderly mainnet fork
            deployerPrivateKey = vm.envUint("MAINNET_PRIVATEKEY");
            deployer = vm.addr(deployerPrivateKey);
            multisig = vm.envAddress("MAINNET_MULTISIG_ADDRESS");
            USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == 11155111) {
            deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATEKEY");
            deployer = vm.addr(deployerPrivateKey);
            multisig = vm.envAddress("SEPOLIA_MULTISIG_ADDRESS");
            USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == 31337) {
            require(deployer != address(0), "Deployer not set");
            multisig = vm.addr(0x987321);
            USDC = vm.envAddress("LOCAL_USDC_ADDRESS");
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
