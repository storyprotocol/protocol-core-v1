// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/// @title IGroupNFT
/// @notice Interface for the IP Group (ERC721) NFT collection that manages Group NFTs representing IP Group.
/// Each Group NFT may represent a IP Group.
/// Group NFTs are ERC721 NFTs that can be minted, transferred, but cannot be burned.
interface IGroupNFT is IERC721Metadata {
    /// @notice Emitted when a IP Group NFT minted.
    /// @param minter The address of the minter of the IP Group NFT
    /// @param receiver The address of the receiver of the Group NFT.
    /// @param tokenId The ID of the minted IP Group NFT.
    event GroupNFTMinted(address indexed minter, address indexed receiver, uint256 indexed tokenId);

    /// @notice Mints a Group NFT.
    /// @param minter The address of the minter.
    /// @param receiver The address of the receiver of the minted Group NFT.
    /// @return groupNftId The ID of the minted Group NFT.
    function mintGroupNft(address minter, address receiver) external returns (uint256 groupNftId);
}
