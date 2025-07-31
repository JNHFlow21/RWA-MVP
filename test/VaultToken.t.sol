// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ChainConfig} from "../script/HelperConfig.s.sol";

import {VaultToken} from "../src/VaultToken.sol";
import {DeployVaultToken} from "../script/DeployVaultToken.s.sol";
import {IVaultToken} from "../src/interfaces/IVaultToken.sol";

contract VaultTokenTest is Test {
    VaultToken vaultToken;
    ChainConfig chainConfig;

    address admin;
    address VAULT_ROLE = makeAddr("VAULT_ROLE");
    address simpleVault = makeAddr("simpleVault");
    address other = makeAddr("other");

    function setUp() public {
        DeployVaultToken deployVaultToken = new DeployVaultToken();
        (vaultToken, chainConfig) = deployVaultToken.run();

        admin = vm.addr(chainConfig.deployerPrivateKey);

        vm.startPrank(admin);
        vaultToken.setVault(simpleVault);
        vm.stopPrank();
    }

    function test_InitialRoles() public view {
        assertTrue(vaultToken.hasRole(vaultToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(vaultToken.hasRole(vaultToken.VAULT_ROLE(), simpleVault));
    }

    function test_setVault_Success() public view {
        assertEq(vaultToken.vault(), simpleVault);
    }

    function test_Mint_Burn_ByVault_Success() public {
        address vault = vaultToken.vault();
        address user = makeAddr("user");

        vm.startPrank(vault);
        vaultToken.mint(user, 1e18);
        assertEq(vaultToken.balanceOf(user), 1e18);
        assertEq(vaultToken.totalSupply(), 1e18);

        vaultToken.burn(user, 4e17);
        assertEq(vaultToken.balanceOf(user), 6e17);
        assertEq(vaultToken.totalSupply(), 6e17);
        vm.stopPrank();
    }

    function test_Revert_OnlyVault() public {
        vm.startPrank(other);
        vm.expectRevert(IVaultToken.IVaultToken__OnlyVault.selector);
        vaultToken.mint(other, 10);

        vm.expectRevert(IVaultToken.IVaultToken__OnlyVault.selector);
        vaultToken.burn(other, 10);
        vm.stopPrank();
    }

    function test_Revert_IVaultToken__ZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(IVaultToken.IVaultToken__ZeroAddress.selector);
        vaultToken.setVault(address(0));
        vm.stopPrank();
    }

    function test_Revert_IVaultToken__VaultAlreadySet() public {
        vm.startPrank(admin);
        vm.expectRevert(IVaultToken.IVaultToken__VaultAlreadySet.selector);
        vaultToken.setVault(simpleVault);
        vm.stopPrank();
    }

    function test_Event_VaultSet() public {
        vm.startPrank(admin);

        VaultToken vt = new VaultToken("RWA-Share", "RWAS", 18, admin);

        // 1. 设定 mask + 发件人  --> 设定要比较哪些参数部分，比如说这里就是比较 事件的第一个indexed参数是true，后面是false
        vm.expectEmit(true, false, false, false, address(vt));
        // 2. 预设一个模版，和后续的真实触发事件做比较  --> 设定和谁进行比较
        emit IVaultToken.VaultSet(simpleVault);
        // 3. 调用被测函数，真实事件将与模板比对
        vt.setVault(simpleVault);

        vm.stopPrank();
    }
}
