// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IHookModule } from "../../../contracts/interfaces/modules/base/IHookModule.sol";
import { BaseModule } from "../../../contracts/modules/BaseModule.sol";

/// @title Mock Token Gated Hook.
/// @notice Hook for ensursing caller is the owner of an NFT token.
contract MockTokenGatedHook is BaseModule, IHookModule {
    using ERC165Checker for address;

    string public constant override name = "MockTokenGatedHook";

    function verify(address caller, bytes calldata data) external view returns (bool) {
        address tokenAddress = abi.decode(data, (address));
        if (caller == address(0)) {
            return false;
        }
        if (!tokenAddress.supportsInterface(type(IERC721).interfaceId)) {
            return false;
        }
        return IERC721(tokenAddress).balanceOf(caller) > 0;
    }

    function validateConfig(bytes calldata configData) external view override {
        address tokenAddress = abi.decode(configData, (address));
        require(tokenAddress.supportsInterface(type(IERC721).interfaceId), "MockTokenGatedHook: Invalid token address");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IHookModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
