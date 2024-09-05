// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ProtocolPauseAdmin
/// @notice Contract that allows the pausing and unpausing of the protocol. It allows adding and removing
/// pausable contracts, which are contracts that implement the `IPausable` interface.
/// @dev The contract is restricted to be used only the admin role defined in the `AccessManaged` contract.
/// NOTE: If a contract is upgraded to remove the `IPausable` interface, it should be removed from the list of pausables
/// before the upgrade, otherwise pause() and unpause() will revert.
interface IProtocolPauseAdmin {
    /// @notice Emitted when a pausable contract is added.
    event PausableAdded(address indexed pausable);
    /// @notice Emitted when a pausable contract is removed.
    event PausableRemoved(address indexed pausable);
    /// @notice Emitted when the protocol is paused.
    event ProtocolPaused();
    /// @notice Emitted when the protocol is unpaused.
    event ProtocolUnpaused();

    /// @notice Adds a pausable contract to the list of pausables.
    function addPausable(address pausable) external;

    /// @notice Removes a pausable contract from the list of pausables.
    function removePausable(address pausable) external;

    /// @notice Pauses the protocol by calling the pause() function on all pausable contracts.
    function pause() external;

    /// @notice Unpauses the protocol by calling the unpause() function on all pausable contracts.
    function unpause() external;

    /// @notice Checks if a pausable contract is registered.
    function isPausableRegistered(address pausable) external view returns (bool);

    /// @notice Returns true if all the pausable contracts are paused.
    function isAllProtocolPaused() external view returns (bool);

    /// @notice Returns the list of pausable contracts.
    function pausables() external view returns (address[] memory);
}
