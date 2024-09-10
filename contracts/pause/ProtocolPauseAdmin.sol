// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ProtocolPausableUpgradeable } from "./ProtocolPausableUpgradeable.sol";

import { IProtocolPauseAdmin } from "../interfaces/pause/IProtocolPauseAdmin.sol";
import { Errors } from "../lib/Errors.sol";

/// @title ProtocolPauseAdmin
/// @notice Contract that allows the pausing and unpausing of the protocol. It allows adding and removing
/// pausable contracts, which are contracts that implement the `IPausable` interface.
/// @dev The contract is restricted to be used only the admin role defined in the `AccessManaged` contract.
/// NOTE: If a contract is upgraded to remove the `IPausable` interface, it should be removed from the list of pausables
/// before the upgrade, otherwise pause() and unpause() will revert.
contract ProtocolPauseAdmin is IProtocolPauseAdmin, AccessManaged {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _pausables;

    constructor(address accessManager) AccessManaged(accessManager) {}

    /// @notice Adds a pausable contract to the list of pausables.
    /// @param pausable The address of the pausable contract.
    function addPausable(address pausable) external restricted {
        if (pausable == address(0)) {
            revert Errors.ProtocolPauseAdmin__ZeroAddress();
        }
        if (ProtocolPausableUpgradeable(pausable).paused()) {
            revert Errors.ProtocolPauseAdmin__AddingPausedContract();
        }
        if (!_pausables.add(pausable)) {
            revert Errors.ProtocolPauseAdmin__PausableAlreadyAdded();
        }
        emit PausableAdded(pausable);
    }

    /// @notice Removes a pausable contract from the list of pausables.
    /// @dev WARNING: If a contract is upgraded to remove the `IPausable` interface, it should be
    /// removed from the list of pausables before the upgrade, otherwise pause() and unpause() will revert.
    /// @param pausable The address of the pausable contract.
    function removePausable(address pausable) external restricted {
        if (!_pausables.remove(pausable)) {
            revert Errors.ProtocolPauseAdmin__PausableNotFound();
        }
        emit PausableRemoved(pausable);
    }

    /// @notice Pauses the protocol by calling the pause() function on all pausable contracts.
    function pause() external restricted {
        uint256 length = _pausables.length();
        for (uint256 i = 0; i < length; i++) {
            ProtocolPausableUpgradeable p = ProtocolPausableUpgradeable(_pausables.at(i));
            if (!p.paused()) {
                p.pause();
            }
        }
        emit ProtocolPaused();
    }

    /// @notice Unpauses the protocol by calling the unpause() function on all pausable contracts.
    function unpause() external restricted {
        uint256 length = _pausables.length();
        for (uint256 i = 0; i < length; i++) {
            ProtocolPausableUpgradeable p = ProtocolPausableUpgradeable(_pausables.at(i));
            if (p.paused()) {
                p.unpause();
            }
        }
        emit ProtocolUnpaused();
    }

    /// @notice Checks if all pausable contracts are paused.
    function isAllProtocolPaused() external view returns (bool) {
        uint256 length = _pausables.length();
        if (length == 0) {
            return false;
        }
        for (uint256 i = 0; i < length; i++) {
            if (!ProtocolPausableUpgradeable(_pausables.at(i)).paused()) {
                return false;
            }
        }
        return true;
    }

    /// @notice Checks if a pausable contract is registered.
    function isPausableRegistered(address pausable) external view returns (bool) {
        return _pausables.contains(pausable);
    }

    /// @notice Checks if a pausable contract is registered.
    function pausables() external view returns (address[] memory) {
        return _pausables.values();
    }
}
