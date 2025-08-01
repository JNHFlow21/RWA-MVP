// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";

contract USDCMockTest is Test {
    USDCMock public usdc;
    address public admin;
    address public user = makeAddr("user");
    address public alice = makeAddr("alice");
    address public bob   = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant INITIAL_SUPPLY = 1e12;

    function setUp() public {
        admin = makeAddr("admin");
        usdc = new USDCMock(admin);
    }

    function test_Decimals() public view{
        assertEq(usdc.decimals(), 6);
    }

    function test_Mint_Success() public view{
        assertEq(usdc.balanceOf(admin), INITIAL_SUPPLY);
        assertEq(usdc.totalSupply(), INITIAL_SUPPLY);
    }

    function test_Transfer_Success() public{
        vm.startPrank(admin);
        usdc.transfer(user, INITIAL_SUPPLY);
        assertEq(usdc.balanceOf(user), INITIAL_SUPPLY);
        assertEq(usdc.balanceOf(admin), 0);
        assertEq(usdc.totalSupply(), INITIAL_SUPPLY);
        vm.stopPrank();
    }

    function test_MintForOtherAddress_Success() public{
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
}