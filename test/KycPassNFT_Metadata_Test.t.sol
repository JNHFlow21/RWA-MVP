// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {KycPassNFT} from "../src/KycPassNFT.sol";
import {IKycPassNFT} from "../src/interfaces/IKycPassNFT.sol";

// 复用合约里用到的工具
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract KycPassNFT_Metadata_Test is Test {
    using Strings for uint256;

    KycPassNFT internal nft;
    address internal admin = makeAddr("admin");
    address internal issuer = makeAddr("issuer");
    address internal user = makeAddr("user");
    address internal other = makeAddr("other");

    // 最小 SVG（绿色/红色），便于编码对比
    string internal constant SVG_VALID = "<svg xmlns='http://www.w3.org/2000/svg' width='300' height='80'>"
        "<rect width='300' height='80' rx='10' fill='#16a34a'/>"
        "<text x='16' y='50' fill='white' font-size='24'>KYC VALID</text>" "</svg>";

    string internal constant SVG_REVOKED = "<svg xmlns='http://www.w3.org/2000/svg' width='300' height='80'>"
        "<rect width='300' height='80' rx='10' fill='#ef4444'/>"
        "<text x='16' y='50' fill='white' font-size='24'>KYC REVOKED</text>" "</svg>";

    IKycPassNFT.PassMeta internal meta;

    function setUp() public {
        // 构造函数直接注入 SVG 模板
        vm.startPrank(admin);
        nft = new KycPassNFT("KYC Pass", "KYCP", admin, SVG_VALID, SVG_REVOKED);
        nft.grantRole(nft.KYC_ISSUER_ROLE(), issuer);
        vm.stopPrank();

        meta = IKycPassNFT.PassMeta({tier: 1, expiresAt: uint64(block.timestamp + 1 days), countryCode: bytes32("CN")});
    }

    /* =================== 辅助：构造期望的 tokenURI =================== */

    function _countryToString(bytes32 cc) internal pure returns (string memory) {
        bytes memory buf = abi.encodePacked(cc);
        uint256 len;
        while (len < buf.length && buf[len] != 0) len++;
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = buf[i];
        }
        return string(out);
    }

    function _expectedTokenURI(uint256 tokenId, IKycPassNFT.PassMeta memory m, bool valid)
        internal
        pure
        returns (string memory)
    {
        string memory img =
            string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(valid ? SVG_VALID : SVG_REVOKED)));

        bytes memory json = abi.encodePacked(
            '{"name":"KYC Pass #',
            tokenId.toString(),
            '",',
            '"description":"Soulbound KYC pass (on-chain SVG via template).",',
            '"image":"',
            img,
            '",',
            '"attributes":[' '{"trait_type":"status","value":"',
            (valid ? "VALID" : "REVOKED"),
            '"},',
            '{"trait_type":"tier","value":"',
            Strings.toString(m.tier),
            '"},',
            '{"trait_type":"country","value":"',
            _countryToString(m.countryCode),
            '"},',
            '{"display_type":"date","trait_type":"expiresAt","value":"',
            Strings.toString(m.expiresAt),
            '"}' "]}"
        );

        return string.concat("data:application/json;base64,", Base64.encode(json));
    }

    /* =================== 1) tokenURI（有效） =================== */

    function test_tokenURI_WhenValid() public {
        vm.prank(issuer);
        uint256 tid = nft.mintPass(user, meta);

        string memory got = nft.tokenURI(tid);
        string memory exp = _expectedTokenURI(tid, meta, true);

        assertEq(got, exp, "tokenURI mismatch when VALID");
    }

    /* =================== 2) tokenURI（过期） =================== */

    function test_tokenURI_AfterExpiry() public {
        vm.prank(issuer);
        uint256 tid = nft.mintPass(user, meta);

        // 快进到过期之后
        vm.warp(block.timestamp + 2 days);

        string memory got = nft.tokenURI(tid);
        string memory exp = _expectedTokenURI(tid, meta, false);

        assertEq(got, exp, "tokenURI mismatch when EXPIRED");
    }

    /* =================== 3) tokenURI（吊销） =================== */

    function test_tokenURI_AfterRevoke() public {
        vm.prank(issuer);
        uint256 tid = nft.mintPass(user, meta);

        vm.prank(issuer);
        nft.revokePass(tid);

        // 被 _burn 后，ownerOf 会 revert；此处验证“吊销后不可再取 tokenURI”
        vm.expectRevert();
        nft.tokenURI(tid);
    }

    /* =================== 4) supportsInterface =================== */

    function test_supportsInterface() public view {
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC721Metadata).interfaceId));
        assertTrue(nft.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(nft.supportsInterface(type(IKycPassNFT).interfaceId));
        assertFalse(nft.supportsInterface(0xffffffff));
    }

    /* =================== 5) SBT 语义（禁转/禁授权） =================== */

    function test_Disable_Transfer_And_Approve() public {
        vm.prank(issuer);
        uint256 tid = nft.mintPass(user, meta);

        // 禁转
        vm.prank(user);
        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        nft.transferFrom(user, other, tid);

        // 禁 safeTransfer
        vm.prank(user);
        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        nft.safeTransferFrom(user, other, tid);

        // 禁授权
        vm.prank(user);
        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        nft.approve(other, tid);

        vm.prank(user);
        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        nft.setApprovalForAll(other, true);
    }
}
