// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IIPGraphACL {
    /// @notice Emitted when whitelisted address which can control allowed or disallowed to access the IPGraph contract.
    /// @param addr The address that was whitelisted.
    event WhitelistedAddress(address addr);

    /// @notice Emitted when whitelisted address is revoked.
    /// @param addr The address that was revoked.
    event RevokedWhitelistedAddress(address addr);

    /// @notice Start access to the IPGraph contract from internal contracts.
    function startInternalAccess() external;

    /// @notice End internal access to the IPGraph contract.
    function endInternalAccess() external;

    /// @notice Check if access to the IPGraph contract is from internal contract.
    function isInternalAccess() external view returns (bool);

    /// @notice Whitelist an address that can allow or disallow access to the IPGraph contract.
    /// @param addr The address to whitelist.
    function whitelistAddress(address addr) external;

    /// @notice Revoke whitelisted address.
    /// @param addr The address to revoke.
    function revokeWhitelistedAddress(address addr) external;

    /// @notice Check if an address is whitelisted.
    /// @param addr The address to check.
    function isWhitelisted(address addr) external view returns (bool);
}
