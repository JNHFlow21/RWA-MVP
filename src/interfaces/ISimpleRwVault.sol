// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IKycPassNFT} from "./IKycPassNFT.sol";
import {IVaultToken} from "./IVaultToken.sol";

/// @title ISimpleRwVault - RWA 极简金库（1:1 申购赎回）接口
/// @notice 仅允许持有有效 KYC 通行证的钱包进行申购/赎回；
///         以 USDC 为基础资产，采用 1:1 的份额记账（MVP），不含 NAV / 排队。
/// @dev 建议实现 ReentrancyGuard、Pausable、AccessControl。
interface ISimpleRwVault {
    // ----------------------- Events -----------------------

    /// @notice 成功存入资金并获得份额
    /// @param user 调用人
    /// @param assets 存入的 USDC 数量
    /// @param shares 铸造的份额数量（MVP: shares == assets）
    event Deposited(address indexed user, uint256 assets, uint256 shares);

    /// @notice 成功赎回资金并销毁份额
    /// @param user 调用人
    /// @param assets 取回的 USDC 数量
    /// @param shares 销毁的份额数量（MVP: shares == assets）
    event Withdrawn(address indexed user, uint256 assets, uint256 shares);

    /// @notice 披露报告链接被更新（IPFS / 网页）
    /// @param newURI 新的披露链接
    event ReportUpdated(string newURI);

    /// @notice 金库暂停/恢复
    event Paused(address account);
    event Unpaused(address account);

    // ----------------------- Errors -----------------------

    error NotAuthorized(); // 非管理员/角色
    error NotKycQualified(); // 未持有有效 KYC 通行证
    error InvalidAmount(); // 金额为 0 或超限
    error InsufficientAssets(); // 金库可用 USDC 不足以兑付
    error SweepNotAllowed(); // 尝试清扫受保护的代币（USDC/份额）
    error PausedError(); // 金库处于暂停态
    error ZeroAddress(); // 零地址非法

    // ----------------------- Views -----------------------

    /// @notice 基础资产（USDC）合约地址
    function asset() external view returns (address);

    /// @notice 份额代币合约地址
    function shareToken() external view returns (IVaultToken);

    /// @notice KYC 通行证合约地址
    function kycPass() external view returns (IKycPassNFT);

    /// @notice 当前披露报告链接（IPFS/网页）
    function reportURI() external view returns (string memory);

    /// @notice 单笔最小/最大存入限制（可选）
    function minDeposit() external view returns (uint256);
    function maxDepositPerTx() external view returns (uint256);

    /// @notice 金库当前托管的 USDC 余额（不含未结算外部资产；MVP 直接读本合约 USDC 余额）
    function totalAssets() external view returns (uint256);

    /// @notice 份额总量（等于 shareToken.totalSupply()）
    function totalShares() external view returns (uint256);

    // ----------------------- Mutations (User) -----------------------

    /// @notice 存入 USDC 并按 1:1 获得份额
    /// @dev 前置条件：
    ///      1) 调用前用户需先对金库执行 USDC approve；
    ///      2) 调用者必须持有有效 KYC 通行证；
    ///      3) 金额需满足 min/max 限制，且金库未暂停。
    /// @param assets 存入 USDC 数量
    /// @return shares 铸造的份额数量（MVP: shares == assets）
    /// @custom:reverts NotKycQualified | InvalidAmount | PausedError
    /// @custom:events Deposited
    /// @custom:security non-reentrant
    function deposit(uint256 assets) external returns (uint256 shares);

    /// @notice 销毁份额并按 1:1 赎回 USDC
    /// @dev 前置条件：
    ///      1) 调用者拥有足够份额；
    ///      2) 金库内 USDC 余额充足；
    ///      3) 金库未暂停（是否允许暂停下赎回由实现决定）。
    /// @param assets 赎回 USDC 数量（MVP: 销毁同额度份额）
    /// @return sharesBurned 实际销毁的份额数量（MVP: == assets）
    /// @custom:reverts InvalidAmount | InsufficientAssets | PausedError
    /// @custom:events Withdrawn
    /// @custom:security non-reentrant
    function withdraw(uint256 assets) external returns (uint256 sharesBurned);

    // ----------------------- Admin / Ops -----------------------

    /// @notice 更新披露报告链接（IPFS/网页）
    /// @param newURI 新链接
    /// @custom:access only-admin
    /// @custom:events ReportUpdated
    function setReportURI(string calldata newURI) external;

    /// @notice 设置单笔存入的最小/最大限制（0 表示不限制）
    /// @custom:access only-admin
    function setDepositLimits(uint256 newMin, uint256 newMaxPerTx) external;

    /// @notice 暂停/恢复金库
    /// @custom:access only-admin
    /// @custom:events Paused | Unpaused
    function pause() external;
    function unpause() external;

    /// @notice 清扫误转到金库的非受保护代币
    /// @dev 禁止清扫：USDC 基础资产、份额代币自身；仅管理员。
    /// @param token ERC20 代币地址
    /// @param amount 清扫数量
    /// @custom:reverts SweepNotAllowed | NotAuthorized
    function sweep(address token, uint256 amount) external;
}
