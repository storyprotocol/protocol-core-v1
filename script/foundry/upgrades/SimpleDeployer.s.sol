// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ModuleRegistry_V2 } from "../../../contracts/registries/ModuleRegistry_V2.sol";

contract SimpleDeployer is Script {
    
    function run() public {
        console2.log("Starting deployment...");
        
        // Deploy the contract
        ModuleRegistry_V2 impl = new ModuleRegistry_V2();
        
        console2.log("ModuleRegistry_V2 deployed at:", address(impl));
        console2.log("Deployment successful!");
    }
} 