// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDCMockTest is Test {
    USDCMock public usdc;
    address public admin;
    address public user = makeAddr("user");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant INITIAL_SUPPLY = 1e12;

    function setUp() public {
        admin = makeAddr("admin");
        usdc = new USDCMock(admin);
    }

    function test_Decimals() public view {
        assertEq(usdc.decimals(), 6);
    }

    function test_Mint_Success() public view {
        assertEq(usdc.balanceOf(admin), INITIAL_SUPPLY);
        assertEq(usdc.totalSupply(), INITIAL_SUPPLY);
    }

    function test_Transfer_Success() public {
        vm.startPrank(admin);
        usdc.transfer(user, INITIAL_SUPPLY);
        assertEq(usdc.balanceOf(user), INITIAL_SUPPLY);
        assertEq(usdc.balanceOf(admin), 0);
        assertEq(usdc.totalSupply(), INITIAL_SUPPLY);
        vm.stopPrank();
    }

    function test_MintForOtherAddress_Success() public {
        vm.startPrank(admin);
        usdc.mint(alice, INITIAL_SUPPLY);
        usdc.mint(bob, INITIAL_SUPPLY);
        usdc.mint(charlie, INITIAL_SUPPLY);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), INITIAL_SUPPLY);
        assertEq(usdc.balanceOf(bob), INITIAL_SUPPLY);
        assertEq(usdc.balanceOf(charlie), INITIAL_SUPPLY);
        assertEq(usdc.totalSupply(), 4e12);
    }

    // test transfer from / approve
    /* ============ A-1 approve 设置 ============ */
    function test_Approve_SetsAllowance() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(alice, bob, INITIAL_SUPPLY);

        usdc.approve(bob, INITIAL_SUPPLY);

        assertEq(usdc.allowance(alice, bob), INITIAL_SUPPLY);
    }

    /* ============ A-2 transferFrom 消耗额度 ============ */
    function test_TransferFrom_ReducesAllowance() public {
        vm.startPrank(admin);
        usdc.mint(alice, INITIAL_SUPPLY);
        usdc.mint(charlie, INITIAL_SUPPLY);
        vm.stopPrank();

        vm.startPrank(alice);
        usdc.approve(bob, INITIAL_SUPPLY);
        vm.stopPrank();

        uint256 aliceBefore = usdc.balanceOf(alice);
        uint256 charlieBefore = usdc.balanceOf(charlie);

        vm.prank(bob);
        usdc.transferFrom(alice, charlie, INITIAL_SUPPLY);

        assertEq(usdc.balanceOf(alice), aliceBefore - INITIAL_SUPPLY);
        assertEq(usdc.balanceOf(charlie), charlieBefore + INITIAL_SUPPLY);
        assertEq(usdc.allowance(alice, bob), 0);
    }
}
