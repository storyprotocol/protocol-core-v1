// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title VaultController interface
interface IVaultController {
    /// @dev Set the ip royalty vault beacon
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param beacon The ip royalty vault beacon address
    function setIpRoyaltyVaultBeacon(address beacon) external;

    /// @dev Upgrades the ip royalty vault beacon
    /// @dev Enforced to be only callable by the upgrader admin
    /// @param newVault The new ip royalty vault beacon address
    function upgradeVaults(address newVault) external;

    /// @notice Returns the ip royalty vault beacon
    /// @return ipRoyaltyVaultBeacon The ip royalty vault beacon address
    function ipRoyaltyVaultBeacon() external view returns (address);
}
