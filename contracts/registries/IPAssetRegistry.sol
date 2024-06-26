// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IIPAccount } from "../interfaces/IIPAccount.sol";
import { IIPAssetRegistry } from "../interfaces/registries/IIPAssetRegistry.sol";
import { ProtocolPausableUpgradeable } from "../pause/ProtocolPausableUpgradeable.sol";
import { IPAccountRegistry } from "../registries/IPAccountRegistry.sol";
import { Errors } from "../lib/Errors.sol";
import { IPAccountStorageOps } from "../lib/IPAccountStorageOps.sol";

/// @title IP Asset Registry
/// @notice This contract acts as the source of truth for all IP registered in
///         Story Protocol. An IP is identified by its contract address, token
///         id, and coin type, meaning any NFT may be conceptualized as an IP.
///         Once an IP is registered into the protocol, a corresponding IP
///         asset is generated, which references an IP resolver for metadata
///         attribution and an IP account for protocol authorization.
///         IMPORTANT: The IP account address, besides being used for protocol
///                    auth, is also the canonical IP identifier for the IP NFT.
/// @custom:oz-upgrades-from contracts/old/v1.0.0.sol:IPAssetRegistry_V1_0_0
contract IPAssetRegistry is IIPAssetRegistry, IPAccountRegistry, ProtocolPausableUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

    /// @dev Storage structure for the IPAssetRegistry
    /// @notice Tracks the total number of IP assets in existence.
    /// @custom:storage-location erc7201:story-protocol.IPAssetRegistry
    struct IPAssetRegistryStorage {
        uint256 totalSupply;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.IPAssetRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IPAssetRegistryStorageLocation =
        0x987c61809af5a42943abd137c7acff8426aab6f7a1f5c967a03d1d718ba5cf00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address erc6551Registry, address ipAccountImpl) IPAccountRegistry(erc6551Registry, ipAccountImpl) {
        _disableInitializers();
    }

    /// @notice Initializes the IPAssetRegistry contract.
    /// @param accessManager The address of the access manager.
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.IPAssetRegistry__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @notice Registers an NFT as an IP asset.
    /// @dev The IP required metadata name and URI are derived from the NFT's metadata.
    /// @param chainid The chain identifier of where the IP NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @return id The address of the newly registered IP.
    function register(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId
    ) external whenNotPaused returns (address id) {
        id = registerIpAccount(chainid, tokenContract, tokenId);
        IIPAccount ipAccount = IIPAccount(payable(id));

        if (bytes(ipAccount.getString("NAME")).length != 0) {
            revert Errors.IPAssetRegistry__AlreadyRegistered();
        }

        (string memory name, string memory uri) = _getNameAndUri(chainid, tokenContract, tokenId);
        uint256 registrationDate = block.timestamp;
        ipAccount.setString("NAME", name);
        ipAccount.setString("URI", uri);
        ipAccount.setUint256("REGISTRATION_DATE", registrationDate);

        _getIPAssetRegistryStorage().totalSupply++;

        emit IPRegistered(id, chainid, tokenContract, tokenId, name, uri, registrationDate);
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
        if (id == address(0)) return false;
        if (id.code.length == 0) return false;
        if (!ERC165Checker.supportsInterface(id, type(IIPAccount).interfaceId)) return false;
        (uint chainId, address tokenContract, uint tokenId) = IIPAccount(payable(id)).token();
        if (id != ipAccount(chainId, tokenContract, tokenId)) return false;
        return bytes(IIPAccount(payable(id)).getString("NAME")).length != 0;
    }

    /// @notice Gets the total number of IP assets registered in the protocol.
    function totalSupply() external view returns (uint256) {
        return _getIPAssetRegistryStorage().totalSupply;
    }

    /// @dev Retrieves the name and URI of from IP NFT.
    function _getNameAndUri(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (string memory name, string memory uri) {
        if (chainid != block.chainid) {
            name = string.concat(chainid.toString(), ": ", tokenContract.toHexString(), " #", tokenId.toString());
            uri = "";
            return (name, uri);
        }
        // Handle NFT on the same chain
        if (!tokenContract.supportsInterface(type(IERC721).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721(tokenContract);
        }

        if (IERC721(tokenContract).ownerOf(tokenId) == address(0)) {
            revert Errors.IPAssetRegistry__InvalidToken(tokenContract, tokenId);
        }

        if (!tokenContract.supportsInterface(type(IERC721Metadata).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721Metadata(tokenContract);
        }

        name = string.concat(
            block.chainid.toString(),
            ": ",
            IERC721Metadata(tokenContract).name(),
            " #",
            tokenId.toString()
        );
        uri = IERC721Metadata(tokenContract).tokenURI(tokenId);
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of IPAssetRegistry.
    function _getIPAssetRegistryStorage() private pure returns (IPAssetRegistryStorage storage $) {
        assembly {
            $.slot := IPAssetRegistryStorageLocation
        }
    }
}
