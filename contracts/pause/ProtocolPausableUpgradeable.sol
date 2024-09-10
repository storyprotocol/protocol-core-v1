// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title ProtocolPausable
/// @notice Contract that allows the pausing and unpausing of the a contract
abstract contract ProtocolPausableUpgradeable is PausableUpgradeable, AccessManagedUpgradeable {
    /// @notice Initializes the ProtocolPausable contract
    /// @param accessManager The address of the access manager
    function __ProtocolPausable_init(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
        __Pausable_init();
    }

    /// @notice sets paused state
    function pause() external restricted {
        _pause();
    }

    /// @notice unsets unpaused state
    function unpause() external restricted {
        _unpause();
    }

    function paused() public view override returns (bool) {
        return super.paused();
    }
}
