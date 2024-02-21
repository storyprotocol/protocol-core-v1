// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC6551Account } from "erc6551/interfaces/IERC6551Account.sol";

import { IIPAccountRegistry } from "../../interfaces/registries/IIPAccountRegistry.sol";
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
        IIPAccountRegistry ipAccountRegistry_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) external view returns (bool) {
        return ipAccountRegistry_.ipAccount(chainId_, tokenContract_, tokenId_).code.length != 0;
    }

    /// @notice Checks if the given address is a valid IP Account.
    /// @param ipAccountRegistry_ The IP Account registry contract.
    /// @param ipAccountAddress_ The address to check.
    /// @return True if the address is a valid IP Account, false otherwise.
    function isIpAccount(
        IIPAccountRegistry ipAccountRegistry_,
        address ipAccountAddress_
    ) external view returns (bool) {
        if (ipAccountAddress_ == address(0)) return false;
        if (ipAccountAddress_.code.length == 0) return false;
        if (!ERC165Checker.supportsERC165(ipAccountAddress_)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IERC6551Account).interfaceId)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IIPAccount).interfaceId)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IIPAccountStorage).interfaceId)) return false;
        (uint chainId, address tokenContract, uint tokenId) = IIPAccount(payable(ipAccountAddress_)).token();
        return ipAccountAddress_ == ipAccountRegistry_.ipAccount(chainId, tokenContract, tokenId);
    }
}
