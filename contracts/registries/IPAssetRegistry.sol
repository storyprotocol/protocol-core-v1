// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IIPAccount } from "../interfaces/IIPAccount.sol";
import { IIPAssetRegistry } from "../interfaces/registries/IIPAssetRegistry.sol";
import { IPAccountRegistry } from "../registries/IPAccountRegistry.sol";
import { IMetadataProviderMigratable } from "../interfaces/registries/metadata/IMetadataProviderMigratable.sol";
import { MetadataProviderV1 } from "../registries/metadata/MetadataProviderV1.sol";
import { Errors } from "../lib/Errors.sol";
import { IResolver } from "../interfaces/resolvers/IResolver.sol";
import { LICENSING_MODULE_KEY } from "../lib/modules/Module.sol";
import { IModuleRegistry } from "../interfaces/registries/IModuleRegistry.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { IIPAssetRegistry } from "../interfaces/registries/IIPAssetRegistry.sol";
import { IRegistrationModule } from "../interfaces/modules/IRegistrationModule.sol";
import { Governable } from "../governance/Governable.sol";

/// @title IP Asset Registry
/// @notice This contract acts as the source of truth for all IP registered in
///         Story Protocol. An IP is identified by its contract address, token
///         id, and coin type, meaning any NFT may be conceptualized as an IP.
///         Once an IP is registered into the protocol, a corresponding IP
///         asset is generated, which references an IP resolver for metadata
///         attribution and an IP account for protocol authorization.
///         IMPORTANT: The IP account address, besides being used for protocol
///                    auth, is also the canonical IP identifier for the IP NFT.
contract IPAssetRegistry is IIPAssetRegistry, IPAccountRegistry, Governable {
    /// @notice The canonical module registry used by the protocol.
    IModuleRegistry public immutable MODULE_REGISTRY;

    /// @notice The registration module that interacts with IPAssetRegistry.
    IRegistrationModule public REGISTRATION_MODULE;

    /// @notice Tracks the total number of IP assets in existence.
    uint256 public totalSupply = 0;

    /// @notice Checks whether an operator is approved to register on behalf of an IP owner.
    mapping(address owner => mapping(address operator => bool)) public isApprovedForAll;

    /// @dev Maps an IP, identified by its IP ID, to an IP record.
    mapping(address => Record) internal _records;

    /// @dev Tracks the current metadata provider used for IP registrations.
    IMetadataProviderMigratable internal _metadataProvider;

    /// TODO: Utilize module registry for fetching different modules.
    constructor(
        address erc6551Registry,
        address ipAccountImpl,
        address moduleRegistry,
        address governance
    ) IPAccountRegistry(erc6551Registry, ipAccountImpl) Governable(governance) {
        MODULE_REGISTRY = IModuleRegistry(moduleRegistry);
        _metadataProvider = IMetadataProviderMigratable(new MetadataProviderV1(address(this)));
    }

    // TODO: Switch to access controller for centralizing this auth mechanism.
    /// @notice Enables third party operators to register on behalf of an NFT owner.
    /// @param operator The address of the operator the sender authorizes.
    /// @param approved Whether or not to approve that operator for registration.
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @dev Sets the registration module that interacts with IPAssetRegistry.
    /// @param registrationModule The address of the registration module.
    function setRegistrationModule(address registrationModule) external onlyProtocolAdmin {
        REGISTRATION_MODULE = IRegistrationModule(registrationModule);
    }

    /// @dev Sets the provider for storage of new IP metadata, while enabling existing IP assets to migrate their
    /// metadata to the new provider.
    /// @param newMetadataProvider Address of the new metadata provider contract.
    function setMetadataProvider(address newMetadataProvider) external onlyProtocolAdmin {
        _metadataProvider.setUpgradeProvider(newMetadataProvider);
        _metadataProvider = IMetadataProviderMigratable(newMetadataProvider);
    }

    /// @notice Registers an NFT as IP, creating a corresponding IP record.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @param resolverAddr The address of the resolver to associate with the IP.
    /// @param createAccount Whether to create an IP account when registering.
    /// @param metadata_ Metadata in bytes to associate with the IP.
    /// @return ipId_ The address of the newly registered IP.
    function register(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address resolverAddr,
        bool createAccount,
        bytes calldata metadata_
    ) external returns (address ipId_) {
        ipId_ = _register(
            new uint256[](0),
            "",
            chainId,
            tokenContract,
            tokenId,
            resolverAddr,
            createAccount,
            metadata_
        );
        emit IPRegistered(ipId_, chainId, tokenContract, tokenId, resolverAddr, address(_metadataProvider), metadata_);
    }

    /// @notice Registers an NFT as an IP using licenses derived from parent IP asset(s).
    /// @param licenseIds The parent IP asset licenses used to derive the new IP asset.
    /// @param royaltyContext The context for the royalty module to process.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @param resolverAddr The address of the resolver to associate with the IP.
    /// @param createAccount Whether to create an IP account when registering.
    /// @param metadata_ Metadata in bytes to associate with the IP.
    /// @return ipId_ The address of the newly registered IP.
    function register(
        uint256[] calldata licenseIds,
        bytes calldata royaltyContext,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address resolverAddr,
        bool createAccount,
        bytes calldata metadata_
    ) external returns (address ipId_) {
        ipId_ = _register(
            licenseIds,
            royaltyContext,
            chainId,
            tokenContract,
            tokenId,
            resolverAddr,
            createAccount,
            metadata_
        );
        emit IPRegistered(ipId_, chainId, tokenContract, tokenId, resolverAddr, address(_metadataProvider), metadata_);
    }

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return ipId The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return super.ipAccount(chainId, tokenContract, tokenId);
    }

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return isRegistered Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool) {
        return _records[id].resolver != address(0);
    }

    /// @notice Gets the resolver bound to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return resolver The IP resolver address if registered, else the zero address.
    function resolver(address id) external view returns (address) {
        return _records[id].resolver;
    }

    /// @notice Gets the metadata provider used for new metadata registrations.
    /// @return metadataProvider The address of the metadata provider used for new IP registrations.
    function metadataProvider() external view returns (address) {
        return address(_metadataProvider);
    }

    /// @notice Gets the metadata provider linked to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return metadataProvider The metadata provider that was bound to this IP at creation time.
    function metadataProvider(address id) external view returns (address) {
        return address(_records[id].metadataProvider);
    }

    /// @notice Gets the underlying canonical metadata linked to an IP asset.
    /// @param id The canonical ID of the IP asset.
    /// @return metadata The metadata that was bound to this IP at creation time.
    function metadata(address id) external view returns (bytes memory) {
        if (address(_records[id].metadataProvider) == address(0)) {
            revert Errors.IPAssetRegistry__NotYetRegistered();
        }
        return _records[id].metadataProvider.getMetadata(id);
    }

    /// @notice Sets the underlying metadata for an IP asset.
    /// @dev As metadata is immutable but additive, this will only be used when an IP migrates from a new provider that
    /// introduces new attributes.
    /// @param id The canonical ID of the IP.
    /// @param data Canonical metadata to associate with the IP.
    function setMetadata(address id, address provider, bytes calldata data) external {
        // Canonical metadata is set on registration and immutable thereafter, with new
        // fields only added during a migration to new protocol-approved metadata provider.
        if (address(_records[id].metadataProvider) != msg.sender) {
            revert Errors.IPAssetRegistry__Unauthorized();
        }
        _setMetadata(id, IMetadataProviderMigratable(provider), data);
    }

    /// @notice Sets the resolver for an IP based on its canonical ID.
    /// @param id The canonical ID of the IP.
    /// @param resolverAddr The address of the resolver being set.
    function setResolver(address id, address resolverAddr) public {
        if (_records[id].resolver == address(0)) {
            revert Errors.IPAssetRegistry__NotYetRegistered();
        }
        // TODO: Update authorization logic to use the access controller.
        address owner = IIPAccount(payable(id)).owner();
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
            revert Errors.IPAssetRegistry__Unauthorized();
        }
        _setResolver(id, resolverAddr);
    }

    /// @dev Registers an NFT as an IP.
    /// @param licenseIds IP asset licenses used to derive the new IP asset, if any.
    /// @param royaltyContext The context for the royalty module to process.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @param resolverAddr The address of the resolver to associate with the IP.
    /// @param createAccount Whether to create an IP account when registering.
    /// @param data Canonical metadata to associate with the IP.
    function _register(
        uint256[] memory licenseIds,
        bytes memory royaltyContext,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address resolverAddr,
        bool createAccount,
        bytes calldata data
    ) internal returns (address id) {
        id = ipId(chainId, tokenContract, tokenId);
        if (_records[id].resolver != address(0)) {
            revert Errors.IPAssetRegistry__AlreadyRegistered();
        }

        address _owner = IERC721(tokenContract).ownerOf(tokenId);
        if (
            msg.sender != _owner && msg.sender != address(REGISTRATION_MODULE) && !isApprovedForAll[_owner][msg.sender]
        ) {
            revert Errors.IPAssetRegistry__RegistrantUnauthorized();
        }

        if (id.code.length == 0 && createAccount && id != registerIpAccount(chainId, tokenContract, tokenId)) {
            revert Errors.IPAssetRegistry__InvalidAccount();
        }
        _setResolver(id, resolverAddr);
        _setMetadata(id, _metadataProvider, data);
        totalSupply++;

        if (licenseIds.length != 0) {
            ILicensingModule licensingModule = ILicensingModule(MODULE_REGISTRY.getModule(LICENSING_MODULE_KEY));
            licensingModule.linkIpToParents(licenseIds, id, royaltyContext);
        }
    }

    /// @dev Sets the resolver for the specified IP.
    /// @param id The canonical ID of the IP.
    /// @param resolverAddr The address of the resolver being set.
    function _setResolver(address id, address resolverAddr) internal {
        ERC165Checker.supportsInterface(resolverAddr, type(IResolver).interfaceId);
        _records[id].resolver = resolverAddr;
        emit IPResolverSet(id, resolverAddr);
    }

    /// @dev Sets the for the specified IP asset.
    /// @param id The canonical identifier for the specified IP asset.
    /// @param provider The metadata provider hosting the data.
    /// @param data The metadata to set for the IP asset.
    function _setMetadata(address id, IMetadataProviderMigratable provider, bytes calldata data) internal {
        _records[id].metadataProvider = provider;
        provider.setMetadata(id, data);
        emit MetadataSet(id, address(provider), data);
    }
}
