// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { BaseModule } from "../BaseModule.sol";
import { Errors } from "../../lib/Errors.sol";
import { IPAccountStorageOps } from "../../lib/IPAccountStorageOps.sol";
import { CORE_METADATA_MODULE_KEY } from "../../lib/modules/Module.sol";
import { ICoreMetadataModule } from "../../interfaces/modules/metadata/ICoreMetadataModule.sol";

/// @title CoreMetadataModule
/// @notice Manages the core metadata for IP assets within the Story Protocol.
/// @dev This contract allows setting core metadata attributes for IP assets.
///      It implements the ICoreMetadataModule interface.
///      The metadata can be set and updated by the owner of the IP asset.
///      The metadata can be frozen to prevent further changes.
contract CoreMetadataModule is
    BaseModule,
    AccessControlled,
    ICoreMetadataModule,
    AccessManagedUpgradeable,
    UUPSUpgradeable
{
    using IPAccountStorageOps for IIPAccount;

    /// @notice Modifier to ensure that metadata can only be changed when mutable.
    modifier onlyMutable(address ipId) {
        if (IIPAccount(payable(ipId)).getBool("IMMUTABLE")) {
            revert Errors.CoreMetadataModule__MetadataAlreadyFrozen();
        }
        _;
    }

    /// @notice Creates a new CoreMetadataModule instance.
    /// @param accessController The address of the AccessController contract.
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {
        _disableInitializers();
    }

    /// @notice Initializes the CoreMetadataModule contract.
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.CoreMetadataModule__ZeroAccessManager();
        }
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    function name() external pure override returns (string memory) {
        return CORE_METADATA_MODULE_KEY;
    }

    /// @notice Update the nftTokenURI for an IP asset,
    /// by retrieve the latest TokenURI from IP NFT to which the IP Asset bound.
    /// @dev Will revert if IP asset's metadata is frozen.
    /// @param ipId The address of the IP asset.
    /// @param nftMetadataHash A bytes32 hash representing the metadata of the NFT.
    /// This metadata is associated with the IP Asset and is accessible via the NFT's TokenURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    function updateNftTokenURI(address ipId, bytes32 nftMetadataHash) external verifyPermission(ipId) {
        _updateNftTokenURI(ipId, nftMetadataHash);
    }

    /// @notice Sets the metadataURI for an IP asset.
    /// @dev Will revert if IP asset's metadata is frozen.
    /// @param ipId The address of the IP asset.
    /// @param metadataURI The metadataURI to set for the IP asset.
    /// @param metadataHash The hash of metadata at metadataURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    function setMetadataURI(
        address ipId,
        string memory metadataURI,
        bytes32 metadataHash
    ) external verifyPermission(ipId) {
        _setMetadataURI(ipId, metadataURI, metadataHash);
    }

    /// @notice Sets all core metadata for an IP asset.
    /// @dev Will revert if IP asset's metadata is frozen.
    /// @param ipId The address of the IP asset.
    /// @param metadataURI The metadataURI to set for the IP asset.
    /// @param metadataHash The hash of metadata at metadataURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    /// @param nftMetadataHash A bytes32 hash representing the metadata of the NFT.
    /// This metadata is associated with the IP Asset and is accessible via the NFT's TokenURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    function setAll(
        address ipId,
        string memory metadataURI,
        bytes32 metadataHash,
        bytes32 nftMetadataHash
    ) external verifyPermission(ipId) {
        _updateNftTokenURI(ipId, nftMetadataHash);
        _setMetadataURI(ipId, metadataURI, metadataHash);
    }

    /// @notice make all metadata of the IP Asset immutable.
    /// @param ipId The address of the IP asset.
    function freezeMetadata(address ipId) external verifyPermission(ipId) {
        IIPAccount(payable(ipId)).setBool("IMMUTABLE", true);
        emit MetadataFrozen(ipId);
    }

    /// @notice Check if the metadata of the IP Asset is immutable.
    /// @param ipId The address of the IP asset.
    function isMetadataFrozen(address ipId) external view returns (bool) {
        return IIPAccount(payable(ipId)).getBool("IMMUTABLE");
    }

    /// @dev Implements the IERC165 interface.
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ICoreMetadataModule).interfaceId || super.supportsInterface(interfaceId);
    }

    function _updateNftTokenURI(address ipId, bytes32 nftMetadataHash) internal onlyMutable(ipId) {
        (, address tokenAddress, uint256 tokenId) = IIPAccount(payable(ipId)).token();
        string memory nftTokenURI = IERC721Metadata(tokenAddress).tokenURI(tokenId);
        IIPAccount(payable(ipId)).setString("NFT_TOKEN_URI", nftTokenURI);
        IIPAccount(payable(ipId)).setBytes32("NFT_METADATA_HASH", nftMetadataHash);
        emit NFTTokenURISet(ipId, nftTokenURI, nftMetadataHash);
    }

    function _setMetadataURI(address ipId, string memory metadataURI, bytes32 metadataHash) internal onlyMutable(ipId) {
        IIPAccount(payable(ipId)).setString("METADATA_URI", metadataURI);
        IIPAccount(payable(ipId)).setBytes32("METADATA_HASH", metadataHash);
        emit MetadataURISet(ipId, metadataURI, metadataHash);
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
