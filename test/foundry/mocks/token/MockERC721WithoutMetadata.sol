// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.8.26;

import { IERC721, IERC165 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract MockERC721WithoutMetadata is IERC721 {
    mapping(uint256 => address) private _owners;

    function mint(address to, uint256 tokenId) external {
        _owners[tokenId] = to;
    }

    function balanceOf(address owner) external view returns (uint256 balance) {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function ownerOf(uint256 tokenId) external view returns (address owner) {
        return _owners[tokenId];
    }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function transferFrom(address from, address to, uint256 tokenId) external {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function approve(address to, uint256 tokenId) external {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function setApprovalForAll(address operator, bool approved) external {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function getApproved(uint256 tokenId) external view returns (address operator) {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        revert("MockERC721WithoutMetadata: not implemented");
    }
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721).interfaceId;
    }
}
