// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNFT is ERC721 {
    uint256 public tokenCounter;
    mapping(uint256 tokenId => string tokenUri) private s_tokenIdToUri;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    // mint
    function mintNFT(string memory tokenUri) public {
        tokenCounter++;
        s_tokenIdToUri[tokenCounter] = tokenUri;
        _safeMint(msg.sender, tokenCounter);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return s_tokenIdToUri[tokenId];
    }
}
