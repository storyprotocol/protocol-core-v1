// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../contracts/Counter.sol";

contract CounterScript is Script {
    Counter public counter;

    function setUp() public {}

    // forge script script/Counter.s.sol:CounterScript --rpc-url https://aeneid.storyrpc.io --broadcast --sender ${SENDER_ADDRESS} --private-key ${PRIVATE_KEY} --priority-gas-price 1 --slow

    function run() public {
        vm.startBroadcast();

        counter = new Counter();

        console.log("Counter deployed at", address(counter));

        vm.stopBroadcast();
    }
}
