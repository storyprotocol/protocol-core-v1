// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC6551Account } from "erc6551/interfaces/IERC6551Account.sol";

import { IIPAssetRegistry } from "../../interfaces/registries/IIPAssetRegistry.sol";
import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IIPAccountStorage } from "../../interfaces/IIPAccountStorage.sol";

/// @title IPAccountChecker
/// @dev This library provides utility functions to check the registration and validity of IP Accounts.
/// It uses the ERC165 standard for contract introspection and the IIPAccountRegistry interface
/// for account registration checks.
library IPAccountChecker {
    /// @notice Returns true if the IPAccount is registered.
    /// @param chainId_ The chain ID where the IP Account is located.
    /// @param tokenContract_ The address of the token contract associated with the IP Account.
    /// @param tokenId_ The ID of the token associated with the IP Account.
    /// @return True if the IP Account is registered, false otherwise.
    function isRegistered(
        IIPAssetRegistry ipAssetRegistry_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) internal view returns (bool) {
        return ipAssetRegistry_.isRegistered(ipAssetRegistry_.ipId(chainId_, tokenContract_, tokenId_));
    }

    /// @notice Checks if the given address is a valid IP Account.
    /// @param ipAssetRegistry_ The IP Account registry contract.
    /// @param ipAccountAddress_ The address to check.
    /// @return True if the address is a valid IP Account, false otherwise.
    function isIpAccount(IIPAssetRegistry ipAssetRegistry_, address ipAccountAddress_) internal view returns (bool) {
        if (ipAccountAddress_ == address(0)) return false;
        if (ipAccountAddress_.code.length == 0) return false;
        if (!ERC165Checker.supportsERC165(ipAccountAddress_)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IERC6551Account).interfaceId)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IIPAccount).interfaceId)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IIPAccountStorage).interfaceId)) return false;
        return ipAssetRegistry_.isRegistered(ipAccountAddress_);
    }
}
