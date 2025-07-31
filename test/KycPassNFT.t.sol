// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {KycPassNFT} from "../src/KycPassNFT.sol";
import {ChainConfig} from "../script/HelperConfig.s.sol";
import {DeployAll} from "../script/DeployAll.s.sol";
import {IKycPassNFT} from "../src/interfaces/IKycPassNFT.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";


contract KycPassNFTTest is Test {
    KycPassNFT kycPassNFT;
    ChainConfig chainConfig;

    address ADMIN;
    address KYC_ISSUER = makeAddr("KYC_ISSUER");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");

    IKycPassNFT.PassMeta meta;

    function setUp() public {
        DeployAll deployAll = new DeployAll();
        (kycPassNFT, chainConfig) = deployAll.run();

        ADMIN = vm.addr(chainConfig.deployerPrivateKey);

        vm.startPrank(ADMIN);
        // 这里有两次调用，1是kycPassNFT.KYC_ISSUER_ROLE() 2是grantRole，prank只能一次
        kycPassNFT.grantRole(kycPassNFT.KYC_ISSUER_ROLE(), KYC_ISSUER);
        vm.stopPrank();

        meta = IKycPassNFT.PassMeta({tier: 1, expiresAt: uint64(block.timestamp + 1 days), countryCode: bytes32("CN")});
    }

    function testInitialRoles() public view {
        assertTrue(kycPassNFT.hasRole(kycPassNFT.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(kycPassNFT.hasRole(kycPassNFT.KYC_ISSUER_ROLE(), ADMIN));
        assertTrue(kycPassNFT.hasRole(kycPassNFT.KYC_ISSUER_ROLE(), KYC_ISSUER));
    }

    function test_MintPass_Success() public {
        vm.startPrank(KYC_ISSUER);
        uint256 tokenId = kycPassNFT.mintPass(USER1, meta);
        vm.stopPrank();

        assertEq(kycPassNFT.passOf(USER1), tokenId);
        assertEq(kycPassNFT.ownerOf(tokenId), USER1);

        (bool ok, IKycPassNFT.PassMeta memory got) = kycPassNFT.hasValidPass(USER1);
        assertTrue(ok);
        assertEq(got.tier, meta.tier);
        assertEq(got.expiresAt, meta.expiresAt);
        assertEq(got.countryCode, meta.countryCode);
    }

    function test_RevokePass_Success() public {
        vm.startPrank(KYC_ISSUER);
        uint256 tokenId = kycPassNFT.mintPass(USER1, meta);

        kycPassNFT.revokePass(tokenId);
        vm.stopPrank();

        // passOf 清空，hasValidPass=false，token 不存在
        assertEq(kycPassNFT.passOf(USER1), 0);
        (bool ok,) = kycPassNFT.hasValidPass(USER1);
        assertFalse(ok);
        vm.expectRevert();
        kycPassNFT.ownerOf(tokenId);
    }

    function test_SBT() public {
        vm.startPrank(KYC_ISSUER);
        uint256 tokenId = kycPassNFT.mintPass(USER1, meta);
        vm.stopPrank();

        // transferfrom && safetransferfrom
        vm.startPrank(USER1);
        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        kycPassNFT.transferFrom(USER1, USER2, tokenId);

        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        kycPassNFT.safeTransferFrom(USER1, USER2, tokenId);

        // approve && setApprovalForAll
        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        kycPassNFT.approve(USER2, tokenId);

        vm.expectRevert(IKycPassNFT.IKycPassNFT__TransferDisabled.selector);
        kycPassNFT.setApprovalForAll(USER2, true);

        vm.stopPrank();
    }

    // 重复mint失败
    function test_Revert_KycPassNFT__AlreadyHasPass() public {
        vm.startPrank(KYC_ISSUER);
        kycPassNFT.mintPass(USER1, meta);

        vm.expectRevert(abi.encodeWithSelector(KycPassNFT.KycPassNFT__AlreadyHasPass.selector, USER1));
        kycPassNFT.mintPass(USER1, meta);
        vm.stopPrank();
    }

    // 其他人不能mint
    function test_Revert_IKycPassNFT__NotAuthorized() public {
        vm.startPrank(USER1);
        vm.expectRevert(IKycPassNFT.IKycPassNFT__NotAuthorized.selector);
        kycPassNFT.mintPass(USER2, meta);
        vm.stopPrank();
    }

    // pass过期
    function test_Revert_IKycPassNFT__InvalidOrExpiredPass() public {
        vm.startPrank(KYC_ISSUER);
        kycPassNFT.mintPass(USER1, meta);

        // 快进到过期之后
        vm.warp(block.timestamp + 2 days);

        (bool ok, ) = kycPassNFT.hasValidPass(USER1);
        assertFalse(ok);
    }

    function test_SupportsInterface() public view{
        assertTrue(kycPassNFT.supportsInterface(type(IERC721).interfaceId));
        assertTrue(kycPassNFT.supportsInterface(type(IERC721Metadata).interfaceId));
        assertTrue(kycPassNFT.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(kycPassNFT.supportsInterface(type(IKycPassNFT).interfaceId));
        assertFalse(kycPassNFT.supportsInterface(0xffffffff));
    }
}
