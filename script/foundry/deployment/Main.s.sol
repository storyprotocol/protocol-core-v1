/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";

// script
import { DeployHelper } from "../utils/DeployHelper.sol";

contract Main is DeployHelper {
    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address internal CREATE3_DEPLOYER = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
    uint256 internal CREATE3_DEFAULT_SEED = 6;
    address internal IP_GRAPH_ACL = address(0x1640A22a8A086747cD377b73954545e2Dfcc9Cad);

    string internal constant VERSION = "v1.3";

    constructor()
        DeployHelper(
            ERC6551_REGISTRY,
            address(0), // replaced with WIP in DeployHelper.sol
            IP_GRAPH_ACL
        )
    {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public virtual {
        _run(CREATE3_DEPLOYER, CREATE3_DEFAULT_SEED);
    }

    function run(uint256 seed) public {
        _run(CREATE3_DEPLOYER, seed);
    }

    function run(address create3Deployer, uint256 seed) public {
        _run(create3Deployer, seed);
    }

    function _run(address create3Deployer, uint256 seed) internal {
        // deploy all contracts via DeployHelper
        super.run(
            create3Deployer,
            seed, // create3 seed
            false, // runStorageLayoutCheck
            true, // writeDeployments,
            VERSION
        );
        _writeDeployment(VERSION); // write deployment json to deployments/deployment-{chainId}.json
    }
}
