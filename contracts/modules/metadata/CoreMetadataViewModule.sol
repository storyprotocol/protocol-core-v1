// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { BaseModule } from "../BaseModule.sol";
import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IPAccountStorageOps } from "../../lib/IPAccountStorageOps.sol";
import { CORE_METADATA_VIEW_MODULE_KEY, CORE_METADATA_MODULE_KEY } from "../../lib/modules/Module.sol";
import { ICoreMetadataViewModule, IViewModule } from "../../interfaces/modules/metadata/ICoreMetadataViewModule.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";

/// @title Implementation of the ICoreMetadataViewModule interface
/// @dev Provides functionalities to retrieve core metadata of IP assets, including name, metadataURI, and more.
contract CoreMetadataViewModule is BaseModule, ICoreMetadataViewModule {
    using IPAccountStorageOps for IIPAccount;

    string public constant override name = CORE_METADATA_VIEW_MODULE_KEY;

    address public immutable IP_ASSET_REGISTRY;
    address public immutable MODULE_REGISTRY;

    address public coreMetadataModule;

    constructor(address ipAssetRegistry, address moduleRegistry) {
        IP_ASSET_REGISTRY = ipAssetRegistry;
        MODULE_REGISTRY = moduleRegistry;
    }

    /// @notice Updates the address of the CoreMetadataModule used by this view module.
    /// @dev Retrieve the address of the CoreMetadataModule from the ModuleRegistry.
    function updateCoreMetadataModule() external {
        coreMetadataModule = IModuleRegistry(MODULE_REGISTRY).getModule(CORE_METADATA_MODULE_KEY);
    }

    /// @notice Retrieves all core metadata of the IPAsset.
    /// @param ipId The address of the IPAsset.
    /// @return The CoreMetadata struct of the IPAsset.
    function getCoreMetadata(address ipId) external view returns (CoreMetadata memory) {
        return
            CoreMetadata({
                nftTokenURI: getNftTokenURI(ipId),
                nftMetadataHash: getNftMetadataHash(ipId),
                metadataURI: getMetadataURI(ipId),
                metadataHash: getMetadataHash(ipId),
                registrationDate: getRegistrationDate(ipId),
                owner: getOwner(ipId)
            });
    }

    /// @notice Retrieves the metadataURI of the IPAsset set by CoreMetadataModule.
    /// @param ipId The address of the IPAsset.
    /// @return The metadataURI of the IPAsset.
    function getMetadataURI(address ipId) public view returns (string memory) {
        return IIPAccount(payable(ipId)).getString(coreMetadataModule, "METADATA_URI");
    }

    /// @notice Retrieves the metadata hash of the IPAsset set by CoreMetadataModule.
    /// @param ipId The address of the IPAsset.
    /// @return The metadata hash of the IPAsset.
    function getMetadataHash(address ipId) public view returns (bytes32) {
        return IIPAccount(payable(ipId)).getBytes32(coreMetadataModule, "METADATA_HASH");
    }

    /// @notice Retrieves the registration date of the IPAsset from IPAssetRegistry.
    /// @param ipId The address of the IPAsset.
    /// @return The registration date of the IPAsset.
    function getRegistrationDate(address ipId) public view returns (uint256) {
        return IIPAccount(payable(ipId)).getUint256(IP_ASSET_REGISTRY, "REGISTRATION_DATE");
    }

    /// @notice Retrieves the TokenURI of NFT to which the IPAsset bound.
    /// preferring the TokenURI from CoreMetadataModule if available.
    /// @param ipId The address of the IPAsset.
    /// @return The NFT TokenURI bound to the IPAsset.
    function getNftTokenURI(address ipId) public view returns (string memory) {
        string memory nftTokenURI = IIPAccount(payable(ipId)).getString(coreMetadataModule, "NFT_TOKEN_URI");
        if (_isEmptyString(nftTokenURI)) {
            nftTokenURI = IIPAccount(payable(ipId)).getString(IP_ASSET_REGISTRY, "URI");
        }
        return nftTokenURI;
    }

    /// @notice Retrieves the NFT metadata hash of the IPAsset set by CoreMetadataModule.
    /// @param ipId The address of the IPAsset.
    /// @return The NFT metadata hash of the IPAsset.
    function getNftMetadataHash(address ipId) public view returns (bytes32) {
        return IIPAccount(payable(ipId)).getBytes32(coreMetadataModule, "NFT_METADATA_HASH");
    }

    /// @notice Retrieves the owner of the IPAsset.
    /// @param ipId The address of the IPAsset.
    /// @return The address of the owner of the IPAsset.
    function getOwner(address ipId) public view returns (address) {
        return IIPAccount(payable(ipId)).owner();
    }

    /// @notice Generates a JSON string formatted according to the standard NFT metadata schema for the IPAsset,
    ////        including all relevant metadata fields.
    /// @dev This function consolidates metadata from both IPAssetRegistry
    ///      and CoreMetadataModule, with "NFT TokenURI" from CoreMetadataModule taking precedence.
    /// @param ipId The address of the IPAsset.
    /// @return A JSON string representing all metadata of the IPAsset.
    function getJsonString(address ipId) external view returns (string memory) {
        string memory baseJson = string(
            /* solhint-disable */
            abi.encodePacked('{"name": "IP Asset # ', Strings.toHexString(ipId), '", "attributes": [')
            /* solhint-enable */
        );

        string memory ipAttributes = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"trait_type": "Owner", "value": "',
                Strings.toHexString(getOwner(ipId)),
                '"},'
                '{"trait_type": "MetadataHash", "value": "',
                Strings.toHexString(uint256(getMetadataHash(ipId)), 32),
                '"},'
                '{"trait_type": "MetadataURI", "value": "',
                getMetadataURI(ipId),
                '"},'
                '{"trait_type": "NFTMetadataHash", "value": "',
                Strings.toHexString(uint256(getNftMetadataHash(ipId)), 32),
                '"},'
                '{"trait_type": "NFTTokenURI", "value": "',
                getNftTokenURI(ipId),
                '"},'
                '{"trait_type": "Registration Date", "value": "',
                Strings.toString(getRegistrationDate(ipId)),
                '"}'
            )
            /* solhint-enable */
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(string(abi.encodePacked(baseJson, ipAttributes, "]}"))))
                )
            );
    }

    /// @notice check whether the view module is supported for the given IP account
    function isSupported(address ipAccount) external view returns (bool) {
        return !_isEmptyString(IIPAccount(payable(ipAccount)).getString(IP_ASSET_REGISTRY, "NAME"));
    }

    /// @dev implement IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return
            interfaceId == type(ICoreMetadataViewModule).interfaceId ||
            interfaceId == type(IViewModule).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @dev Checks if a string is empty
    function _isEmptyString(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }
}
