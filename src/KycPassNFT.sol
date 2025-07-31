// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IKycPassNFT} from "./interfaces/IKycPassNFT.sol";

contract KycPassNFT is IKycPassNFT, ERC721, AccessControl {
    // ---------- Roles ----------
    bytes32 public constant KYC_ISSUER_ROLE = keccak256("KYC_ISSUER_ROLE");

    // ---------- Extra Errors ----------
    error KycPassNFT__AlreadyHasPass(address user);
    error KycPassNFT__NonexistentPass(uint256 tokenId);

    // ---------- Storage ----------
    /// @notice 一个地址最多持有一张通行证；0 表示无证
    mapping(address => uint256 tokenId) public passOf;

    /// @notice 通行证轻量元数据
    mapping(uint256 tokenId => PassMeta) private _passMeta;

    /// @dev 自增的 tokenId 计数器（从 1 开始，便于用 0 表示无证）
    uint256 private _tokenIdCounter;

    /// @dev 可选：元数据基地址（如 "ipfs://..."），仅演示用途
    string private _baseTokenURI;

    // ---------- Constructor ----------
    constructor(string memory name_, string memory symbol_, address admin) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KYC_ISSUER_ROLE, admin);
    }

    // ---------- IKycPassNFT: Views ----------
    /// @inheritdoc IKycPassNFT
    function hasValidPass(address user) public view override returns (bool ok, PassMeta memory meta) {
        uint256 tid = passOf[user];
        if (tid == 0) return (false, meta);
        meta = _passMeta[tid];
        // 有效条件：未设置过期 或 当前时间未超过 expiresAt
        ok = (meta.expiresAt == 0 || block.timestamp <= meta.expiresAt);
    }

    /// @inheritdoc IKycPassNFT
    function passMetaOf(uint256 tokenId) external view override returns (PassMeta memory) {
        if (_ownerOf(tokenId) == address(0)) revert KycPassNFT__NonexistentPass(tokenId);
        return _passMeta[tokenId];
    }

    /// @inheritdoc IKycPassNFT
    /// @dev 让别的合约或前端在链上“问你”：你是不是实现了某个接口？
    /// @dev 支持 IKycPassNFT 接口，以及 ERC721 和 AccessControl 接口
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl, IKycPassNFT)
        returns (bool)
    {
        return interfaceId == type(IKycPassNFT).interfaceId || ERC721.supportsInterface(interfaceId)
            || AccessControl.supportsInterface(interfaceId);
    }

    // ---------- IKycPassNFT: Mutations ----------
    /// @inheritdoc IKycPassNFT
    function mintPass(address to, PassMeta calldata meta) external override returns (uint256 tokenId) {
        // 自定义权限检查
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(KYC_ISSUER_ROLE, msg.sender)) {
            revert IKycPassNFT__NotAuthorized();
        }
        if (to == address(0)) revert IKycPassNFT__NotAuthorized();
        if (passOf[to] != 0) revert KycPassNFT__AlreadyHasPass(to);

        tokenId = ++_tokenIdCounter; // 从 1 开始
        _passMeta[tokenId] = meta;
        passOf[to] = tokenId;

        _safeMint(to, tokenId);
        emit PassIssued(to, tokenId, meta);
    }

    /// @inheritdoc IKycPassNFT
    function revokePass(uint256 tokenId) external override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(KYC_ISSUER_ROLE, msg.sender)) {
            revert IKycPassNFT__NotAuthorized();
        }
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) revert KycPassNFT__NonexistentPass(tokenId);

        delete passOf[owner];
        delete _passMeta[tokenId];

        _burn(tokenId);
        emit PassRevoked(tokenId);
    }

    // ---------- SBT 语义：禁止用户↔用户转让 ----------
    /**
     * @dev OZ v5 的统一转移入口。仅允许 mint（from=0）或 burn（to=0），禁止 from!=0 && to!=0 的场景。
     * 就是全局的权限校验，写出校验规则，调用父类的方法就好了
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = _ownerOf(tokenId); // 读取转移前的 owner（mint 时为 0，burn 时 to 为 0）
        if (from != address(0) && to != address(0)) {
            revert IKycPassNFT__TransferDisabled();
        }
        return super._update(to, tokenId, auth);
    }

    /// @dev 禁止创建授权，避免“可转让”的错觉
    function approve(address, uint256) public pure override {
        revert IKycPassNFT__TransferDisabled();
    }

    function setApprovalForAll(address, bool) public pure override {
        revert IKycPassNFT__TransferDisabled();
    }
}
