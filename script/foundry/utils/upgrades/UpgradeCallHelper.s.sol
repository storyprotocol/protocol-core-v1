// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";

import { JsonDeploymentHandler } from "../JsonDeploymentHandler.s.sol";
import { UpgradedImplHelper } from "./UpgradedImplHelper.sol";

contract ScheduleCallHelper is Script, JsonDeploymentHandler {
    
    string constant NAMESPACE = "story-protocol";
    string constant CONTRACT_NAME = "AccessControllerV2";

    constructor() JsonDeploymentHandler("main") {}

    function run() external {
        _readProposalFile("1.1.0");
        logScheduleCall(_readUpgradeProposal("AccessController"));
        logScheduleCall(_readUpgradeProposal("IPAssetRegistry"));
        logScheduleCall(_readUpgradeProposal("IpRoyaltyVault"));
        logScheduleCall(_readUpgradeProposal("LicenseRegistry"));
        logScheduleCall(_readUpgradeProposal("LicenseToken"));
        logScheduleCall(_readUpgradeProposal("LicensingModule"));
        logScheduleCall(_readUpgradeProposal("PILicenseTemplate"));
        logScheduleCall(_readUpgradeProposal("RoyaltyModule"));
        logScheduleCall(_readUpgradeProposal("RoyaltyPolicyLAP"));

    }

    function logScheduleCall(UpgradedImplHelper.UpgradeProposal memory proposal) internal pure {
        console2.log(proposal.key);
        console2.log("Proxy");
        console2.log(proposal.proxy);
        if (keccak256(abi.encodePacked(proposal.key)) == keccak256(abi.encodePacked("IpRoyaltyVault"))) {
            console2.log("Schedule upgradeVaults");
            console2.logBytes(abi.encodeCall(RoyaltyPolicyLAP.upgradeVaults, proposal.newImpl));
        } else {
            console2.log("Schedule upgradeUUPS");
            console2.logBytes(abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (proposal.newImpl, "")));
        }

    }
}
