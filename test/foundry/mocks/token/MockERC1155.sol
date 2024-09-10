// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.8.26;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    function mintId(address to, uint256 tokenId, uint256 value) public returns (uint256) {
        _mint(to, tokenId, value, "");
        return tokenId;
    }

    function burn(address from, uint256 tokenId, uint256 value) public {
        _burn(from, tokenId, value);
    }
}
