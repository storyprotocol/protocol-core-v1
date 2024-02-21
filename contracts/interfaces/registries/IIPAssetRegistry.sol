// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IIPAccountRegistry } from "./IIPAccountRegistry.sol";
import { IModuleRegistry } from "./IModuleRegistry.sol";
import { IMetadataProviderMigratable } from "./metadata/IMetadataProviderMigratable.sol";
import { IRegistrationModule } from "../modules/IRegistrationModule.sol";

/// @title Interface for IP Account Registry
/// @notice This interface manages the registration and tracking of IP Accounts
interface IIPAssetRegistry is IIPAccountRegistry {
    // TODO: Deprecate `resolver` in favor of consolidation through the provider.
    /// @notice Attributes for the IP asset type.
    /// @param metadataProvider Metadata provider for Story Protocol canonicalized metadata.
    /// @param resolver Metadata resolver for custom metadata added by the IP owner.
    struct Record {
        IMetadataProviderMigratable metadataProvider;
        address resolver;
    }

    // TODO: Add support for optional licenseIds.
    /// @notice Emits when an IP is officially registered into the protocol.
    /// @param ipId The canonical identifier for the IP.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @param resolver The address of the resolver linked to the IP.
    /// @param provider The address of the metadata provider linked to the IP.
    /// @param metadata Canonical metadata that was linked to the IP.
    event IPRegistered(
        address ipId,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        address resolver,
        address provider,
        bytes metadata
    );

    /// @notice Emits when an IP resolver is bound to an IP.
    /// @param ipId The canonical identifier of the specified IP.
    /// @param resolver The address of the new resolver bound to the IP.
    event IPResolverSet(address ipId, address resolver);

    /// @notice Emits when an operator is approved for IP registration for an NFT owner.
    /// @param owner The address of the IP owner.
    /// @param operator The address of the operator the owneris authorizing.
    /// @param approved Whether or not to approve that operator for registration.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Emits when metadata is set for an IP asset.
    /// @param ipId The canonical identifier of the specified IP.
    /// @param metadataProvider Address of the metadata provider associated with the IP.
    /// @param metadata The canonical metadata in bytes associated with the IP.
    event MetadataSet(address indexed ipId, address indexed metadataProvider, bytes metadata);

    /// @notice The canonical module registry used by the protocol.
    function MODULE_REGISTRY() external view returns (IModuleRegistry);

    /// @notice The registration module that interacts with IPAssetRegistry.
    function REGISTRATION_MODULE() external view returns (IRegistrationModule);

    /// @notice Tracks the total number of IP assets in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Checks whether an operator is approved to register on behalf of an IP owner.
    /// @param owner The address of the IP owner whose approval is being checked for.
    /// @param operator The address of the operator the owner has approved for registration delgation.
    /// @return Whether the operator is approved on behalf of the owner for registering.
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /// @notice Enables third party operators to register on behalf of an NFT owner.
    /// @param operator The address of the operator the sender authorizes.
    /// @param approved Whether or not to approve that operator for registration.
    function setApprovalForAll(address operator, bool approved) external;

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
    ) external returns (address);

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
    ) external returns (address);

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return ipId The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address);

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return isRegistered Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool);

    /// @notice Gets the resolver bound to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return resolver The IP resolver address if registered, else the zero address.
    function resolver(address id) external view returns (address);

    /// @notice Gets the metadata provider used for new metadata registrations.
    /// @return metadataProvider The address of the metadata provider used for new IP registrations.
    function metadataProvider() external view returns (address);

    /// @notice Gets the metadata provider linked to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return metadataProvider The metadata provider that was bound to this IP at creation time.
    function metadataProvider(address id) external view returns (address);

    /// @notice Gets the underlying canonical metadata linked to an IP asset.
    /// @param id The canonical ID of the IP asset.
    /// @return metadata The metadata that was bound to this IP at creation time.
    function metadata(address id) external view returns (bytes memory);

    /// @notice Sets the underlying metadata for an IP asset.
    /// @dev As metadata is immutable but additive, this will only be used when an IP migrates from a new provider that
    /// introduces new attributes.
    /// @param id The canonical ID of the IP.
    /// @param data Canonical metadata to associate with the IP.
    function setMetadata(address id, address metadataProvider, bytes calldata data) external;

    /// @notice Sets the resolver for an IP based on its canonical ID.
    /// @param id The canonical ID of the IP.
    /// @param resolverAddr The address of the resolver being set.
    function setResolver(address id, address resolverAddr) external;
}
