// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { IGroupingModule } from "./interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupNFT } from "./interfaces/IGroupNFT.sol";
import { Errors } from "./lib/Errors.sol";

/// @title GroupNFT
contract GroupNFT is IGroupNFT, ERC721Upgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for *;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupingModule public immutable GROUPING_MODULE;

    /// @notice Emitted for metadata updates, per EIP-4906
    event BatchMetadataUpdate(uint256 indexed _fromTokenId, uint256 indexed _toTokenId);

    /// @dev Storage structure for the GroupNFT
    /// @custom:storage-location erc7201:story-protocol.GroupNFT
    struct GroupNFTStorage {
        string imageUrl;
        uint256 totalSupply;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.GroupNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GroupNFTStorageLocation =
        0x1f63c78b3808749cafddcb77c269221c148dbaa356630c2195a6ec03d7fedb00;

    modifier onlyGroupingModule() {
        if (msg.sender != address(GROUPING_MODULE)) {
            revert Errors.GroupNFT__CallerNotGroupingModule(msg.sender);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address groupingModule) {
        GROUPING_MODULE = IGroupingModule(groupingModule);
        _disableInitializers();
    }

    /// @dev Initializes the GroupNFT contract
    function initialize(address accessManager, string memory imageUrl) public initializer {
        if (accessManager == address(0)) {
            revert Errors.GroupNFT__ZeroAccessManager();
        }
        __ERC721_init("Programmable IP Group IP NFT", "GroupNFT");
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
        _getGroupNFTStorage().imageUrl = imageUrl;
    }

    /// @dev Sets the Licensing Image URL.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param url The URL of the Licensing Image
    function setLicensingImageUrl(string calldata url) external restricted {
        GroupNFTStorage storage s = _getGroupNFTStorage();
        s.imageUrl = url;
        emit BatchMetadataUpdate(0, s.totalSupply);
    }

    /// @notice Mints a Group NFT.
    /// @param minter The address of the minter.
    /// @param receiver The address of the receiver of the minted Group NFT.
    /// @return groupNftId The ID of the minted Group NFT.
    function mintGroupNft(address minter, address receiver) external onlyGroupingModule returns (uint256 groupNftId) {
        GroupNFTStorage storage s = _getGroupNFTStorage();
        groupNftId = s.totalSupply++;
        _mint(receiver, groupNftId);
        emit GroupNFTMinted(minter, receiver, groupNftId);
    }

    /// @notice Returns the total number of minted group IPA NFT since beginning,
    /// @return The total number of minted group IPA NFT.
    function totalSupply() external view returns (uint256) {
        return _getGroupNFTStorage().totalSupply;
    }

    /// @notice ERC721 OpenSea metadata JSON representation of Group IPA NFT
    function tokenURI(
        uint256 id
    ) public view virtual override(ERC721Upgradeable, IERC721Metadata) returns (string memory) {
        if (!_exists(id)) {
            revert Errors.GroupNFT__NonExistentToken(id);
        }

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, id.toString())) : "";
    }

    /// @dev Internal helper function to retrieve the GroupNFTStorage struct
    function _getGroupNFTStorage() internal pure returns (GroupNFTStorage storage s) {
        assembly {
            s.slot := GroupNFTStorageLocation
        }
    }

    /// @dev Implementation of the `_beforeTokenTransfer` hook used by ERC721Upgradeable.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        // Additional logic can be placed here if necessary
    }

    /// @dev Implementation of the `_burn` hook used by ERC721Upgradeable.
    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
        // Additional logic can be placed here if necessary
    }

    /// @dev Returns the base URI for all tokens.
    function _baseURI() internal view virtual returns (string memory) {
        return _getGroupNFTStorage().imageUrl;
    }
}
