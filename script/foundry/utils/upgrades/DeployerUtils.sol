// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";

contract DeployerUtils {

    ERC6551Registry internal immutable erc6551Registry;
    ICreate3Deployer internal immutable create3Deployer;
    // seed for CREATE3 salt
    uint256 internal create3SaltSeed;

    constructor(
        address _erc6551Registry,
        address _create3Deployer,
        uint256 _create3SaltSeed
    ) {
        erc6551Registry = ERC6551Registry(_erc6551Registry);
        create3Deployer = ICreate3Deployer(_create3Deployer);
        create3SaltSeed = _create3SaltSeed;
    }

    function _getSalt(string memory name) internal virtual view returns (bytes32 salt) {
        console2.log(name);
        salt = keccak256(abi.encode(name, create3SaltSeed));
        console2.logBytes32(salt);
    }


}
