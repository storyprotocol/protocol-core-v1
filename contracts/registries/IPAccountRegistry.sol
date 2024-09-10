// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";

import { IIPAccountRegistry } from "../interfaces/registries/IIPAccountRegistry.sol";
import { Errors } from "../lib/Errors.sol";

/// @title IPAccountRegistry
/// @notice This contract is responsible for managing the registration and tracking of IP Accounts.
/// It leverages a public ERC6551 registry to deploy IPAccount contracts.
abstract contract IPAccountRegistry is IIPAccountRegistry {
    /// @notice Returns the IPAccount implementation address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable IP_ACCOUNT_IMPL;

    /// @notice Returns the IPAccount salt
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    bytes32 public immutable IP_ACCOUNT_SALT;

    /// @notice Returns the public ERC6551 registry address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable ERC6551_PUBLIC_REGISTRY;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address erc6551Registry, address ipAccountImpl) {
        if (ipAccountImpl == address(0)) revert Errors.IPAccountRegistry_ZeroIpAccountImpl();
        if (erc6551Registry == address(0)) revert Errors.IPAccountRegistry_ZeroERC6551Registry();
        IP_ACCOUNT_IMPL = ipAccountImpl;
        IP_ACCOUNT_SALT = bytes32(0);
        ERC6551_PUBLIC_REGISTRY = erc6551Registry;
    }

    /// @notice Returns the IPAccount address for the given NFT token.
    /// @param chainId The chain ID where the IP Account is located
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    /// @return ipAccountAddress The address of the IP Account associated with the given NFT token
    function ipAccount(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return _get6551AccountAddress(chainId, tokenContract, tokenId);
    }

    /// @notice Returns the IPAccount implementation address.
    /// @return The address of the IPAccount implementation
    function getIPAccountImpl() external view override returns (address) {
        return IP_ACCOUNT_IMPL;
    }

    /// @dev Deploys an IPAccount contract with the IPAccount implementation and returns the address of the new IP
    /// The IPAccount deployment delegates to public ERC6551 Registry
    /// @param chainId The chain ID where the IP Account will be created
    /// @param tokenContract The address of the token contract to be associated with the IP Account
    /// @param tokenId The ID of the token to be associated with the IP Account
    /// @return ipAccountAddress The address of the newly created IP Account
    function _registerIpAccount(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal returns (address ipAccountAddress) {
        ipAccountAddress = IERC6551Registry(ERC6551_PUBLIC_REGISTRY).createAccount(
            IP_ACCOUNT_IMPL,
            IP_ACCOUNT_SALT,
            chainId,
            tokenContract,
            tokenId
        );
        emit IPAccountRegistered(ipAccountAddress, IP_ACCOUNT_IMPL, chainId, tokenContract, tokenId);
    }

    /// @dev Helper function to get the IPAccount address from the ERC6551 registry.
    function _get6551AccountAddress(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (address) {
        return
            IERC6551Registry(ERC6551_PUBLIC_REGISTRY).account(
                IP_ACCOUNT_IMPL,
                IP_ACCOUNT_SALT,
                chainId,
                tokenContract,
                tokenId
            );
    }
}
