/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";

contract UpgradedImplHelper {
    struct UpgradeProposal {
        string key;
        address proxy;
        address newImpl;
        // bytes initCall; TODO
    }

    // Upgrade tracking
    UpgradeProposal[] public upgradeProposals;

    function _addProposal(
        string memory key,
        address proxy,
        address newImpl
    ) internal {
        require(proxy != address(0), "UpgradeImplHelper: Invalid proxy address");
        require(newImpl != address(0), "UpgradeImplHelper: Invalid new implementation address");
        upgradeProposals.push(
            UpgradeProposal({
                key: key,
                proxy: proxy,
                newImpl: newImpl
            })
        );
    }

    function _logUpgradeProposals() internal view {
        console2.log("Upgrade Proposals");
        console2.log("Count", upgradeProposals.length);
        for (uint256 i = 0; i < upgradeProposals.length; i++) {
            console2.log("Proposal");
            console2.log(upgradeProposals[i].key);
            if (keccak256(abi.encodePacked(upgradeProposals[i].key)) == keccak256(abi.encodePacked("IpRoyaltyVault"))) {
                console2.log("BeaconProxy");
            } else {
                console2.log("Proxy");
            }
            console2.log(upgradeProposals[i].proxy);
            console2.log("New Impl");
            console2.log(upgradeProposals[i].newImpl);
        }
    }
}
