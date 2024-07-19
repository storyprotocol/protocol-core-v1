// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { Users, UsersLib } from "../../../test/foundry/utils/Users.t.sol";

import { StringUtil } from "./StringUtil.sol";
import { MockERC20 } from "../../../test/foundry/mocks/token/MockERC20.sol";

contract BroadcastManager is Script {
    address public multisig;
    address public deployer;
    address public relayer;
    uint32 public upgraderExecDelay;

    function _beginBroadcast() internal {
        uint256 deployerPrivateKey;
        if (block.chainid == 1) { // Tenderly mainnet fork
            deployerPrivateKey = vm.envUint("MAINNET_PRIVATEKEY");
            deployer = vm.addr(deployerPrivateKey);
            multisig = vm.envAddress("MAINNET_MULTISIG_ADDRESS");
            upgraderExecDelay = uint32(vm.envUint("MAINNET_UPGRADER_EXEC_DELAY"));
            relayer = vm.envAddress("MAINNET_RELAYER_ADDRESS");
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == 11155111) {
            deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATEKEY");
            deployer = vm.addr(deployerPrivateKey);
            multisig = vm.envAddress("SEPOLIA_MULTISIG_ADDRESS");
            relayer = vm.envAddress("SEPOLIA_RELAYER_ADDRESS");
            upgraderExecDelay = 10 minutes;
            vm.startBroadcast(deployerPrivateKey);
        } else if (block.chainid == vm.envUint("CHAIN_ID")) {
            deployerPrivateKey = vm.envUint("CHAIN_ADMIN_ADDRESS");
            deployer = vm.addr(deployerPrivateKey);
            multisig = vm.envAddress("CHAIN_MULTISIG_ADDRESS");
            // relayer = vm.envAddress("CHAIN_RELAYER_ADDRESS");
            upgraderExecDelay = 10 minutes;
            vm.startBroadcast(vm.envUint("CHAIN_MULTISIG_PRIVATEKEY"));
        } else if (block.chainid == 31337) {
            Users memory u = UsersLib.createMockUsers(vm);
            // DeployHelper.sol will set the final admin as the multisig, so we do this for coherence
            // with the tests (DeployHelper.sol is used both in tests and in the deployment scripts)
            multisig = u.admin;
            deployer = u.alice;
            relayer = u.relayer;
            upgraderExecDelay = 10 minutes;
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
