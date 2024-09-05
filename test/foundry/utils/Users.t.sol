// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Vm } from "forge-std/Vm.sol";

struct Users {
    // Default admin
    address payable admin;
    // Random users
    address payable alice;
    address payable bob;
    address payable carl;
    address payable dan;
    // Malicious user
    address payable eve;
    // Relayer
    address payable relayer;
}

library UsersLib {
    function createUser(string memory name, Vm vm) public returns (address payable user) {
        user = payable(address(uint160(uint256(keccak256(abi.encodePacked(name))))));
        vm.deal(user, 100 ether); // set balance to 100 ether
        vm.label(user, name);
        return user;
    }

    function createMockUsers(Vm vm) public returns (Users memory) {
        return
            Users({
                // admin: payable(address(123)), // same as AccessControlHelper.sol (123 => 0x7b)
                admin: createUser("Admin", vm),
                alice: createUser("Alice", vm),
                bob: createUser("Bob", vm),
                carl: createUser("Carl", vm),
                dan: createUser("Dan", vm),
                eve: createUser("Eve", vm),
                relayer: createUser("Relayer", vm)
            });
    }
}
