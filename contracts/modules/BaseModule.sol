// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165, ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IModule } from "../interfaces/modules/base/IModule.sol";

/// @title BaseModule
/// @notice Base implementation for all modules in Story Protocol.
abstract contract BaseModule is ERC165, IModule {
    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
