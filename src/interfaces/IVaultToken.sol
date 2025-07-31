// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IVaultToken - RWA 金库份额代币（ERC-20）接口
/// @notice 表示金库中的“份额”。MVP 下 1 份额 = 1 USDC（1:1）。
/// @dev 仅金库合约可铸造/销毁；建议 decimals 与 USDC 保持一致（6）。
interface IVaultToken {
    // ----------------------- Events -----------------------

    /// @notice 设置/更新唯一铸销者（金库）地址
    /// @param vault 新的金库地址
    event VaultSet(address indexed vault);

    // ----------------------- Errors -----------------------

    /// @notice 非金库地址调用了仅金库可用的函数
    error OnlyVault();

    /// @notice 零地址非法
    error ZeroAddress();

    // ----------------------- Views -----------------------

    /// @notice 份额代币小数位（建议返回 6）
    function decimals() external view returns (uint8);

    /// @notice 当前金库地址
    function vault() external view returns (address);

    /// @notice ERC-20 标准视图
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);

    // ----------------------- ERC-20 Mutations -----------------------

    /// @notice 标准 ERC-20 授权/转账（用户间转让是否受限由金库业务决定）
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // ----------------------- Vault-only -----------------------

    /// @notice 铸造份额至指定账户（仅金库）
    /// @param to 接收地址
    /// @param shares 份额数量
    /// @custom:access only-vault
    function mint(address to, uint256 shares) external;

    /// @notice 从指定账户销毁份额（仅金库）
    /// @param from 被销毁地址
    /// @param shares 份额数量
    /// @custom:access only-vault
    function burn(address from, uint256 shares) external;

    /// @notice 设置金库地址（仅一次或仅管理员；由实现决定）
    /// @param newVault 金库合约地址
    /// @custom:access only-admin (或 构造函数一次性设定)
    /// @custom:events VaultSet
    function setVault(address newVault) external;
}
