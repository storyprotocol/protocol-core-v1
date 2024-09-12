/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";

// script
import { DeployHelper } from "../utils/DeployHelper.sol";

contract Main is DeployHelper {
    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;
    uint256 internal CREATE3_DEFAULT_SEED = 0;
    // For arbitration policy
    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 USDC
    address internal constant TREASURY_ADDRESS = address(200);
    // For royalty policy
    uint256 internal constant MAX_ROYALTY_APPROVAL = 10000 ether;
    string internal constant VERSION = "v1.2";

    constructor()
        DeployHelper(
            ERC6551_REGISTRY,
            CREATE3_DEPLOYER,
            address(0), // replaced with USDC in DeployHelper.sol
            ARBITRATION_PRICE,
            MAX_ROYALTY_APPROVAL,
            TREASURY_ADDRESS
        )
    {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public virtual override {
        _run(CREATE3_DEFAULT_SEED);
    }

    function run(uint256 seed) public {
        _run(seed);
    }

    function _run(uint256 seed) internal {
        // deploy all contracts via DeployHelper
        super.run(
            seed, // create3 seed
            false, // runStorageLayoutCheck
            true // writeDeployments,
        );
        _writeDeployment(VERSION); // write deployment json to deployments/deployment-{chainId}.json
    }
}
