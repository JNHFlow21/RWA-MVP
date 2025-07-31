// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title IVaultToken - RWA 金库份额代币（ERC-20）接口
/// @notice 表示金库中的“份额”。MVP 下 1 份额 = 1 USDC（1:1）。
/// @dev
/// - 仅金库合约可铸造/销毁；实现应限制为 vault() 才能调用 {mint}/{burn}。
/// - 建议 decimals 与 USDC 保持一致（6），以便 1:1 直连；后续也可扩展为 18 位统一方案。
/// - 建议 setVault 仅允许绑定一次，防止被换绑劫持。
interface IVaultToken is IERC20, IERC20Metadata {
    // ----------------------- Events -----------------------

    /// @notice 设置/更新唯一铸销者（金库）地址（推荐：仅触发一次）
    /// @param vault 新的金库地址
    event VaultSet(address indexed vault);

    // ----------------------- Errors -----------------------

    /// @notice 非金库地址调用了仅金库可用的函数
    error IVaultToken__OnlyVault();

    /// @notice 零地址非法
    error IVaultToken__ZeroAddress();

    /// @notice 金库地址已设置，不可重复设置
    error IVaultToken__VaultAlreadySet();

    // ----------------------- Views -----------------------

    /// @notice 当前金库地址
    function vault() external view returns (address);

    // ----------------------- Vault-only -----------------------

    /// @notice 铸造份额至指定账户（仅金库）
    /// @param to 接收地址
    /// @param shares 份额数量（建议与底层资产单位一致）
    /// @custom:access only-vault
    function mint(address to, uint256 shares) external;

    /// @notice 从指定账户销毁份额（仅金库）
    /// @param from 被销毁地址
    /// @param shares 份额数量（建议与底层资产单位一致）
    /// @custom:access only-vault
    function burn(address from, uint256 shares) external;

    /// @notice 绑定金库地址（建议：仅允许一次；或仅管理员）
    /// @param newVault 金库合约地址
    /// @custom:access only-admin (或 构造函数一次性设定)
    /// @custom:events VaultSet
    function setVault(address newVault) external;
}