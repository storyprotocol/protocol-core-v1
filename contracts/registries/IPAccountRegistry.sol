// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IIPAccountRegistry } from "../interfaces/registries/IIPAccountRegistry.sol";
import { Errors } from "../lib/Errors.sol";

/// @title IPAccountRegistry
/// @notice This contract is responsible for managing the registration and tracking of IP Accounts.
/// It leverages a public ERC6551 registry to deploy IPAccount contracts.
abstract contract IPAccountRegistry is IIPAccountRegistry, Initializable {
    /// @notice Returns the current IPAccount implementation address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable CURRENT_IP_ACCOUNT_IMPL;

    /// @notice Returns the IPAccount salt
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    bytes32 public immutable IP_ACCOUNT_SALT;

    /// @notice Returns the public ERC6551 registry address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable ERC6551_PUBLIC_REGISTRY;

    // @dev Storage structure for the IPAccountRegistry
    /// @custom:storage-location erc7201:story-protocol.IPAccountRegistry
    struct IPAccountRegistryStorage {
        mapping(address => bool) legacyIPAccountImpls;
        mapping(bytes32 => address) registeredNFTsImpls;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.IPAccountRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IPAccountRegistryStorageLocation =
        0xf893abfe903060526ef89f585f926eabf001a2825da700d2d2ccb92d6c666400;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address erc6551Registry, address ipAccountImpl) {
        if (ipAccountImpl == address(0)) revert Errors.IPAccountRegistry_ZeroIpAccountImpl();
        if (erc6551Registry == address(0)) revert Errors.IPAccountRegistry_ZeroERC6551Registry();
        CURRENT_IP_ACCOUNT_IMPL = ipAccountImpl;
        IP_ACCOUNT_SALT = bytes32(0);
        ERC6551_PUBLIC_REGISTRY = erc6551Registry;
    }

    /// @notice Returns the IPAccount address for the given NFT token.
    /// @param chainId The chain ID where the IP Account is located
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    /// @return ipAccountAddress The address of the IP Account associated with the given NFT token
    function ipAccount(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return
            IERC6551Registry(ERC6551_PUBLIC_REGISTRY).account(
                CURRENT_IP_ACCOUNT_IMPL,
                IP_ACCOUNT_SALT,
                chainId,
                tokenContract,
                tokenId
            );
    }

    /// @notice Returns the IPAccount address for the given NFT token, with the IPAccount implementation address.
    /// This methods allows support of legacy implementations.
    /// @param chainId The chain ID where the IP Account is located
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    /// @return ipAccountAddress The address of the IP Account associated with the given NFT token,
    /// Zero address if unsupported ipAccountImpl
    function ipAccount(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address ipAccountImpl
    ) public view returns (address) {
        if (!isIpAccountImplSupported(ipAccountImpl)) return address(0);
        return
            IERC6551Registry(ERC6551_PUBLIC_REGISTRY).account(
                ipAccountImpl,
                IP_ACCOUNT_SALT,
                chainId,
                tokenContract,
                tokenId
            );
    }

    /// @notice Returns the current IPAccount implementation address.
    /// @return The address of the IPAccount implementation
    function getIPAccountImpl() external view override returns (address) {
        return CURRENT_IP_ACCOUNT_IMPL;
    }

    /// @notice Returns true if the IPAccount implementation is supported (either current or legacy).
    function isIpAccountImplSupported(address ipAccountImpl) public view returns (bool) {
        return
            ipAccountImpl == CURRENT_IP_ACCOUNT_IMPL ||
            _getIPAccountRegistryStorage().legacyIPAccountImpls[ipAccountImpl];
    }

    /// @notice Helper function to calculate an id representing of an NFT.
    /// @param chainId The chain ID where the NFT is located
    /// @param tokenContract The address of the token contract associated with the NFT
    /// @param tokenId The ID of the token associated with the NFT
    /// @return nftRepresentation The hashed representation of the NFT
    function _nftRepresentation(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(chainId, tokenContract, tokenId));
    }

    /// @notice Returns the IPAccount implementation address for the given NFT token.
    /// @param chainId The chain ID where the IP Account is located
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    /// @return ipAccountAddress The address of the IP Account implementation associated with the given NFT token
    function _getIPAccountImplForNft(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (address) {
        return _getIPAccountRegistryStorage().registeredNFTsImpls[_nftRepresentation(chainId, tokenContract, tokenId)];
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
        bytes32 nftRepresentation = _nftRepresentation(chainId, tokenContract, tokenId);
        if (_getIPAccountRegistryStorage().registeredNFTsImpls[nftRepresentation] != address(0))
            revert Errors.IPAccountRegistry__AlreadyRegistered();
        ipAccountAddress = IERC6551Registry(ERC6551_PUBLIC_REGISTRY).createAccount(
            CURRENT_IP_ACCOUNT_IMPL,
            IP_ACCOUNT_SALT,
            chainId,
            tokenContract,
            tokenId
        );
        _getIPAccountRegistryStorage().registeredNFTsImpls[nftRepresentation] = CURRENT_IP_ACCOUNT_IMPL;
        emit IPAccountRegistered(ipAccountAddress, CURRENT_IP_ACCOUNT_IMPL, chainId, tokenContract, tokenId);
    }

    /// @dev WARNING: This should only be called as part of the upgrade process, by an authorized account.
    function _moveCurrentImplToLegacy() internal {
        _getIPAccountRegistryStorage().legacyIPAccountImpls[CURRENT_IP_ACCOUNT_IMPL] = true;
    }

    /// @dev Returns the storage struct of IPAccountRegistry.
    function _getIPAccountRegistryStorage() private pure returns (IPAccountRegistryStorage storage $) {
        assembly {
            $.slot := IPAccountRegistryStorageLocation
        }
    }
}
