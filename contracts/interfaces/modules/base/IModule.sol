// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @notice Module Interface
interface IModule is IERC165 {
    /// @notice Returns the string identifier associated with the module.
    function name() external returns (string memory);
}
