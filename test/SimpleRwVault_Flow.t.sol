// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployLib} from "../script/DeployLib.sol";
import {SimpleRwVault} from "../src/SimpleRwVault.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {KycPassNFT} from "../src/KycPassNFT.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {DeployAll} from "../script/DeployAll.s.sol";
import {ChainConfig} from "../script/HelperConfig.s.sol";
import {IKycPassNFT} from "../src/interfaces/IKycPassNFT.sol";
import {ISimpleRwVault} from "../src/interfaces/ISimpleRwVault.sol";

contract SimpleRwVault_Flow is Test {
    address public admin;
    address public kycIssuer;
    address public user = makeAddr("user");
    address public other = makeAddr("other");

    DeployLib.DeployConfig deployConfig;
    ChainConfig chainConfig;

    uint256 public constant INITIAL_SUPPLY = 1e12;
    uint256 public constant DEPOSIT_AMOUNT = 1e6;
    IKycPassNFT.PassMeta public meta = IKycPassNFT.PassMeta({
        tier: 1,
        expiresAt: uint64(block.timestamp + 1 days),
        countryCode: bytes32("CN")
    });

    function setUp() public {
        DeployAll deployAll = new DeployAll();
        (deployConfig, chainConfig) = deployAll.run();
        admin = vm.addr(chainConfig.deployerPrivateKey);
        kycIssuer = admin;

        vm.startPrank(admin);
        // 给user kyc pass
        deployConfig.pass.mintPass(user, meta);
        // 给user usdc
        deployConfig.usdc.mint(user, INITIAL_SUPPLY);
        vm.stopPrank();
        // 让 user 给vault approve usdc, 因为只有vault才可以 share交互
        vm.prank(user);
        deployConfig.usdc.approve(address(deployConfig.vault), type(uint256).max);
    }

    function test_Approve_Success() public view{
        assertEq(deployConfig.usdc.allowance(user, address(deployConfig.vault)), type(uint256).max);
    }

    function test_Deposit_Success() public {
        // user可以成功deposit
        vm.startPrank(user);

        uint256 beforeBalance = deployConfig.usdc.balanceOf(user);
        uint256 beforeShares = deployConfig.share.balanceOf(user);

        uint256 shares = deployConfig.vault.deposit(DEPOSIT_AMOUNT);

        uint256 afterBalance = deployConfig.usdc.balanceOf(user);
        uint256 afterShares = deployConfig.share.balanceOf(user);

        vm.stopPrank();

        // shares 增加 / usdc 减少
        assertEq(afterBalance, beforeBalance - DEPOSIT_AMOUNT);
        assertEq(afterShares, beforeShares + shares);

    }

    function test_Withdraw_Success() public {
        vm.startPrank(user);
        // deposit
        uint256 shares = deployConfig.vault.deposit(DEPOSIT_AMOUNT);

        //withdraw
        uint256 beforeBalance = deployConfig.usdc.balanceOf(user);
        uint256 beforeShares = deployConfig.share.balanceOf(user);

        uint256 assets = deployConfig.vault.withdraw(shares);

        uint256 afterBalance = deployConfig.usdc.balanceOf(user);
        uint256 afterShares = deployConfig.share.balanceOf(user);

        vm.stopPrank();

        assertEq(afterBalance, beforeBalance + assets);
        assertEq(afterShares, beforeShares - shares);
    }

    // 限额 min / max
    function test_Deposit_Limits() public {

        uint256 minDepositPerTx = 1e2;
        uint256 maxDepositPerTx = 1e7;
        uint256 succDepositAmount = 1e6;
        uint256 failDepositAmount = 1e1;

        vm.startPrank(admin);
        deployConfig.vault.setDepositLimits(minDepositPerTx, maxDepositPerTx);
        vm.stopPrank();

        vm.startPrank(user);

        vm.expectRevert(ISimpleRwVault.ISimpleRwVault__InvalidAmount.selector);
        deployConfig.vault.deposit(failDepositAmount);

        deployConfig.vault.deposit(succDepositAmount);
        vm.stopPrank();

        assertEq(deployConfig.vault.minDeposit(), minDepositPerTx);
        assertEq(deployConfig.vault.maxDepositPerTx(), maxDepositPerTx);
    }
}
