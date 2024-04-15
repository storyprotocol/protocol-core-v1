// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Empty Implementation
/// @notice This contract is an empty implementation that is intended to be used
/// ONLY to break circular dependencies in the upgradeable contracts.
contract EmptyImpl is UUPSUpgradeable {

    error Unauthorized();

    address immutable public DEPLOYER;

    constructor() {
        DEPLOYER = msg.sender;
        _disableInitializers();
    }
    
    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override {
        if (msg.sender != DEPLOYER) {
            revert Unauthorized();
        }
    }
}
