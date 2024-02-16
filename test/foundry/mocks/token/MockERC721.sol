// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.8.23;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _counter;

    constructor(string memory name) ERC721(name, name) {
        _counter = 0;
    }

    function mint(address to) public returns (uint256 tokenId) {
        tokenId = ++_counter;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function mintId(address to, uint256 tokenId) public returns (uint256) {
        _safeMint(to, tokenId);
        return tokenId;
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        _transfer(from, to, tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://storyprotocol.xyz/erc721/";
    }
}
