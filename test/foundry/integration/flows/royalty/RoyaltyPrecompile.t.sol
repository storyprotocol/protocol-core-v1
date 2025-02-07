// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { RoyaltyModule } from "contracts/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { RoyaltyPolicyLRP } from "contracts/modules/royalty/policies/LRP/RoyaltyPolicyLRP.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { BaseTest } from "../../../utils/BaseTest.t.sol";
import { TestProxyHelper } from "test/foundry/utils/TestProxyHelper.sol";

contract TestRoyaltyPrecompile is BaseTest {

    function setUp() public override {
        super.setUp();
        // Fork the mainnet
        uint256 forkId = vm.createFork("https://aeneid.storyrpc.io/");
        vm.selectFork(forkId);
        // Aeneid
        address wip = 0x1514000000000000000000000000000000000000;
        address royaltyModuleProxy = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
        address royaltyPolicyLAPProxy = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
        address royaltyPolicyLRPProxy = 0x9156e603C949481883B1d3355c6f1132D191fC41;
        address accessManager = 0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53; // protocol access manager
        
        address upgrader = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
        

        // deploy implementation contracts
        address newRoyaltyModuleImpl = address(new RoyaltyModule(
            address(licensingModule), 
            address(disputeModule), 
            address(licenseRegistry), 
            address(ipAssetRegistry), 
            address(ipGraphACL)
        ));

        address newRoyaltyPolicyLAPImpl = address(new RoyaltyPolicyLAP(
            address(royaltyModule),
            address(ipGraphACL)
        ));

        address newRoyaltyPolicyLRPImpl = address(new RoyaltyPolicyLRP(
            address(royaltyModule),
            address(royaltyPolicyLAP),
            address(ipGraphACL)
        ));

        // make upgrade
        vm.startPrank(upgrader);
        (bytes32 operationId, uint32 nonce) = AccessManager(accessManager).schedule(
            royaltyModuleProxy,
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newRoyaltyModuleImpl), abi.encodeCall(RoyaltyModule.initialize, (address(protocolAccessManager), uint256(15))))),
            0 // earliest time possible
        );
        vm.warp(block.timestamp + 1000);

        UUPSUpgradeable(royaltyModuleProxy).upgradeToAndCall(address(newRoyaltyModuleImpl), abi.encodeCall(RoyaltyModule.initialize, (address(protocolAccessManager), uint256(15))));
        vm.stopPrank();
    }
}