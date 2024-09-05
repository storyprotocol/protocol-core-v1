// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { IVaultController } from "../../../interfaces/modules/royalty/policies/IVaultController.sol";
import { ProtocolPausableUpgradeable } from "../../../pause/ProtocolPausableUpgradeable.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Vault Controller
/// @notice Abstract contract that defines the common logic for royalty policies with ip royalty vaults
abstract contract VaultController is IVaultController, ProtocolPausableUpgradeable {
    /// @dev Storage structure for the VaultController
    /// @param ipRoyaltyVaultBeacon The ip royalty vault beacon address
    /// @param snapshotInterval The minimum timestamp interval between snapshots
    /// @custom:storage-location erc7201:story-protocol.VaultController
    struct VaultControllerStorage {
        address ipRoyaltyVaultBeacon;
        uint256 snapshotInterval;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.VaultController")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant VaultControllerStorageLocation =
        0x88cf5a7bd03e240c4fc740fb2d1a8664ec6fa4816f867d60f968080755fb1700;

    /// @dev Set the snapshot interval
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param timestampInterval The minimum timestamp interval between snapshots
    function setSnapshotInterval(uint256 timestampInterval) external restricted {
        VaultControllerStorage storage $ = _getVaultControllerStorage();
        $.snapshotInterval = timestampInterval;
    }

    /// @dev Set the ip royalty vault beacon
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param beacon The ip royalty vault beacon address
    function setIpRoyaltyVaultBeacon(address beacon) external restricted {
        if (beacon == address(0)) revert Errors.VaultController__ZeroIpRoyaltyVaultBeacon();
        VaultControllerStorage storage $ = _getVaultControllerStorage();
        $.ipRoyaltyVaultBeacon = beacon;
    }

    /// @dev Upgrades the ip royalty vault beacon
    /// @dev Enforced to be only callable by the upgrader admin
    /// @param newVault The new ip royalty vault beacon address
    function upgradeVaults(address newVault) external restricted {
        // UpgradeableBeacon already checks for newImplementation.bytecode.length > 0,
        // no need to check for zero address
        VaultControllerStorage storage $ = _getVaultControllerStorage();
        UpgradeableBeacon($.ipRoyaltyVaultBeacon).upgradeTo(newVault);
    }

    /// @notice Returns the snapshot interval
    /// @return snapshotInterval The minimum time interval between snapshots
    function snapshotInterval() public view returns (uint256) {
        return _getVaultControllerStorage().snapshotInterval;
    }

    /// @notice Returns the ip royalty vault beacon
    /// @return ipRoyaltyVaultBeacon The ip royalty vault beacon address
    function ipRoyaltyVaultBeacon() public view returns (address) {
        return _getVaultControllerStorage().ipRoyaltyVaultBeacon;
    }

    /// @dev Returns the storage struct of VaultController.
    function _getVaultControllerStorage() private pure returns (VaultControllerStorage storage $) {
        assembly {
            $.slot := VaultControllerStorageLocation
        }
    }
}
