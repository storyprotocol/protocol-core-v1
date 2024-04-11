/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";

// script
import { DeployHelper } from "../utils/DeployHelper.sol";

contract Main is DeployHelper {
    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    // For arbitration policy
    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 USDC
    // For royalty policy
    uint256 internal constant MAX_ROYALTY_APPROVAL = 10000 ether;

    constructor()
        DeployHelper(
            ERC6551_REGISTRY,
            address(0), // replaced with USDC in DeployHelper.sol
            ARBITRATION_PRICE,
            MAX_ROYALTY_APPROVAL
        )
    {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public virtual override {
        // deploy all contracts via DeployHelper
        super.run(
            true, // runStorageLayoutCheck
            true // writeDeployments
        );
        _writeDeployment(); // write deployment json to deployments/deployment-{chainId}.json
        _endBroadcast(); // BroadcastManager.s.sol
    }
}
