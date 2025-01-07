// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { ProtocolPausableUpgradeable } from "./ProtocolPausableUpgradeable.sol";
import { IProtocolPauseAdmin } from "../interfaces/pause/IProtocolPauseAdmin.sol";
import { Errors } from "../lib/Errors.sol";

/// @title ProtocolPauseAdmin
/// @notice Contract that allows the pausing and unpausing of the protocol. It allows adding and removing
/// pausable contracts, which are contracts that implement the `IPausable` interface.
/// @dev The contract is restricted to be used only the admin role defined in the `AccessManaged` contract.
/// NOTE: If a contract is upgraded to remove the `IPausable` interface, it should be removed from the list of pausables
/// before the upgrade, otherwise pause() and unpause() will revert.
contract ProtocolPauseAdmin is IProtocolPauseAdmin, AccessManagedUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Storage structure for the ProtocolPauseAdmin
    /// @param pausables The set of pausable protocol contracts.
    /// @custom:storage-location erc7201:story-protocol.ProtocolPauseAdmin
    struct ProtocolPauseAdminStorage {
        EnumerableSet.AddressSet pausables;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.ProtocolPauseAdmin")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ProtocolPauseAdminStorageLocation =
        0x21a1ce30504c30a5d878e4adeffc53ac58042f0b1f9b9f100fe7bde5203d9400;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the ProtocolPauseAdmin contract.
    /// @param accessManager The address of the access manager contract.
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) revert Errors.ProtocolPauseAdmin__ZeroAccessManager();

        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @notice Adds a pausable contract to the list of pausables.
    /// @param pausable The address of the pausable contract.
    function addPausable(address pausable) external restricted {
        if (pausable == address(0)) {
            revert Errors.ProtocolPauseAdmin__ZeroAddress();
        }
        if (ProtocolPausableUpgradeable(pausable).paused()) {
            revert Errors.ProtocolPauseAdmin__AddingPausedContract();
        }
        ProtocolPauseAdminStorage storage $ = _getProtocolPauseAdminStorage();
        if (!$.pausables.add(pausable)) {
            revert Errors.ProtocolPauseAdmin__PausableAlreadyAdded();
        }
        emit PausableAdded(pausable);
    }

    /// @notice Removes a pausable contract from the list of pausables.
    /// @dev WARNING: If a contract is upgraded to remove the `IPausable` interface, it should be
    /// removed from the list of pausables before the upgrade, otherwise pause() and unpause() will revert.
    /// @param pausable The address of the pausable contract.
    function removePausable(address pausable) external restricted {
        ProtocolPauseAdminStorage storage $ = _getProtocolPauseAdminStorage();
        if (!$.pausables.remove(pausable)) {
            revert Errors.ProtocolPauseAdmin__PausableNotFound();
        }
        emit PausableRemoved(pausable);
    }

    /// @notice Pauses the protocol by calling the pause() function on all pausable contracts.
    function pause() external restricted {
        ProtocolPauseAdminStorage storage $ = _getProtocolPauseAdminStorage();
        uint256 length = $.pausables.length();
        for (uint256 i = 0; i < length; i++) {
            ProtocolPausableUpgradeable p = ProtocolPausableUpgradeable($.pausables.at(i));
            if (!p.paused()) {
                p.pause();
            }
        }
        emit ProtocolPaused();
    }

    /// @notice Unpauses the protocol by calling the unpause() function on all pausable contracts.
    function unpause() external restricted {
        ProtocolPauseAdminStorage storage $ = _getProtocolPauseAdminStorage();
        uint256 length = $.pausables.length();
        for (uint256 i = 0; i < length; i++) {
            ProtocolPausableUpgradeable p = ProtocolPausableUpgradeable($.pausables.at(i));
            if (p.paused()) {
                p.unpause();
            }
        }
        emit ProtocolUnpaused();
    }

    /// @notice Checks if all pausable contracts are paused.
    function isAllProtocolPaused() external view returns (bool) {
        ProtocolPauseAdminStorage storage $ = _getProtocolPauseAdminStorage();
        uint256 length = $.pausables.length();
        if (length == 0) {
            return false;
        }
        for (uint256 i = 0; i < length; i++) {
            if (!ProtocolPausableUpgradeable($.pausables.at(i)).paused()) {
                return false;
            }
        }
        return true;
    }

    /// @notice Checks if a pausable contract is registered.
    function isPausableRegistered(address pausable) external view returns (bool) {
        ProtocolPauseAdminStorage storage $ = _getProtocolPauseAdminStorage();
        return $.pausables.contains(pausable);
    }

    /// @notice Checks if a pausable contract is registered.
    function pausables() external view returns (address[] memory) {
        ProtocolPauseAdminStorage storage $ = _getProtocolPauseAdminStorage();
        return $.pausables.values();
    }

    ////////////////////////////////////////////////////////////////////////////
    //                         Upgrades related                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @dev Returns the storage struct of ProtocolPauseAdmin.
    function _getProtocolPauseAdminStorage() private pure returns (ProtocolPauseAdminStorage storage $) {
        assembly {
            $.slot := ProtocolPauseAdminStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
