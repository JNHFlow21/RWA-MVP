// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IKycPassNFT} from "./interfaces/IKycPassNFT.sol";
import {ISimpleRwVault} from "./interfaces/ISimpleRwVault.sol";
import {IVaultToken} from "./interfaces/IVaultToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract SimpleRwVault is ISimpleRwVault, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 private _asset; //USDC
    IVaultToken private _share; // VaultToken
    IKycPassNFT private _kyc;

    string private _reportURI; //信息披露网址
    uint256 private _minDeposit; // 单笔最小；0 表示不限,防止 dust attack
    uint256 private _maxDepositPerTx; // 单笔最大；0 表示不限

    constructor(
        IERC20 usdc,
        IVaultToken share,
        IKycPassNFT kyc,
        address admin,
        string memory initialReportURI,
        uint256 minDep,
        uint256 maxDepPerTx
    ) {
        // 检查0地址
        if (
            address(usdc) == address(0) || address(share) == address(0) || address(kyc) == address(0)
                || admin == address(0)
        ) {
            revert ISimpleRwVault__ZeroAddress();
        }

        // 赋值
        _asset = usdc;
        _share = share;
        _kyc = kyc;

        _reportURI = initialReportURI;
        _minDeposit = minDep;
        _maxDepositPerTx = maxDepPerTx;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISimpleRwVault
    function asset() external view returns (IERC20) {
        return _asset;
    }

    /// @inheritdoc ISimpleRwVault
    function shareToken() external view returns (IVaultToken) {
        return _share;
    }

    /// @inheritdoc ISimpleRwVault
    function kycPass() external view returns (IKycPassNFT) {
        return _kyc;
    }

    /// @inheritdoc ISimpleRwVault
    function reportURI() external view returns (string memory) {
        return _reportURI;
    }

    /// @inheritdoc ISimpleRwVault
    function minDeposit() external view returns (uint256) {
        return _minDeposit;
    }

    /// @inheritdoc ISimpleRwVault
    function maxDepositPerTx() external view returns (uint256) {
        return _maxDepositPerTx;
    }

    /// @inheritdoc ISimpleRwVault
    function totalAssets() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /// @inheritdoc ISimpleRwVault
    function totalShares() public view returns (uint256) {
        return _share.totalSupply();
    }

    /// @inheritdoc ISimpleRwVault
    function paused() public view override(Pausable, ISimpleRwVault) returns (bool) {
        return super.paused();
    }

    function deposit(uint256 assets) external nonReentrant returns (uint256) {
        // 判断是否暂停
        if (paused()) revert ISimpleRwVault__PausedError();

        // 判断 asset>0 && asset 是在合理区间之内
        if (assets == 0) revert ISimpleRwVault__InvalidAmount();
        if (_minDeposit != 0 && assets < _minDeposit) revert ISimpleRwVault__InvalidAmount();
        if (_maxDepositPerTx != 0 && assets > _maxDepositPerTx) revert ISimpleRwVault__InvalidAmount();

        // 验证kyc
        (bool ok,) = _kyc.hasValidPass(msg.sender);
        if (!ok) revert ISimpleRwVault__NotKycQualified();

        // 先收钱
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        uint256 shares = assets;

        // 铸币
        _share.mint(msg.sender, shares);

        emit Deposited(msg.sender, assets, shares);
        return shares;
    }

    function withdraw(uint256 assets) external nonReentrant returns (uint256) {
        // 判断assets>0 以及在合理区间
        if (assets == 0) revert ISimpleRwVault__InvalidAmount();
        if (totalAssets() < assets) revert ISimpleRwVault__InsufficientAssets();

        // 先销份额，再把 USDC 转出给用户（CEI 顺序）
        _share.burn(msg.sender, assets);

        _asset.safeTransfer(msg.sender, assets);

        emit Withdrawn(msg.sender, assets, assets);
        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN / OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISimpleRwVault
    function setReportURI(string calldata newURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _reportURI = newURI;
        emit ReportUpdated(newURI);
    }

    /// @inheritdoc ISimpleRwVault
    function setDepositLimits(uint256 newMin, uint256 newMaxPerTx) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMaxPerTx != 0 && newMin > newMaxPerTx) revert ISimpleRwVault__InvalidAmount();
        _minDeposit = newMin;
        _maxDepositPerTx = newMaxPerTx;
    }

    /// @inheritdoc ISimpleRwVault
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause(); // 事件由 Pausable 发出：Paused(account)
    }

    /// @inheritdoc ISimpleRwVault
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause(); // 事件由 Pausable 发出：Unpaused(account)
    }

    /// @inheritdoc ISimpleRwVault
    function sweep(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ISimpleRwVault__ZeroAddress();

        // 受保护资产不可清扫：USDC 与 份额代币自身
        if (token == address(_asset) || token == address(_share)) revert ISimpleRwVault__SweepNotAllowed();

        IERC20(token).safeTransfer(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE / FALLBACK GUARD
    //////////////////////////////////////////////////////////////*/

    /// @dev 纯 ERC-20 金库，避免误转 ETH
    receive() external payable {
        revert("SimpleRwVault: ETH not accepted");
    }

    fallback() external payable {
        revert("SimpleRwVault: ETH not accepted");
    }
}
