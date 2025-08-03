// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IKycPassNFT} from "./interfaces/IKycPassNFT.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract KycPassNFT is IKycPassNFT, ERC721, AccessControl {
    using Strings for uint256;
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

    /// @dev Metadata基地址
    string private constant _BASE_TOKEN_URI = "data:application/json;base64,";
    string private constant _BASE_IMAGE_URI = "data:image/svg+xml;base64,";

    string private svgValid;
    string private svgRevoke;

    // ---------- Constructor ----------
    constructor(
        string memory name_,
        string memory symbol_,
        address admin,
        string memory svgValid_,
        string memory svgRevoke_
    ) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KYC_ISSUER_ROLE, admin);
        svgValid = svgValid_;
        svgRevoke = svgRevoke_;
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

    function _countryToString(bytes32 cc) internal pure returns (string memory) {
        // 把 bytes32 先打包成 bytes，方便逐字节遍历
        bytes memory buf = abi.encodePacked(cc);

        // 计算实际长度（遇到 0x00 视为终止）
        uint256 len = 0;
        while (len < buf.length && buf[len] != 0) {
            len++;
        }

        // 拷贝出有效部分
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = buf[i];
        }
        return string(out);
    }

    // ---------- tokenURI：动态选择模板并组装 JSON ----------
    // svg -> base64svg -> baseImageUri+base64svg -> json -> base64json -> baseTokenUri+base64json = tokenURI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address holder = _requireOwned(tokenId);
        (bool ok, PassMeta memory m) = hasValidPass(holder);

        // 1) 选模板并转为 data:image
        string memory svg = ok ? svgValid : svgRevoke;

        string memory imgURI = string.concat(_BASE_IMAGE_URI, Base64.encode(bytes(svg)));

        // 2) 组装 metadata（最少包含 name/description/image）
        bytes memory json = abi.encodePacked(
            '{"name":"KYC Pass #',
            tokenId.toString(),
            '",',
            '"description":"Soulbound KYC pass (on-chain SVG via template).",',
            '"image":"',
            imgURI,
            '",',
            '"attributes":[' '{"trait_type":"status","value":"',
            (ok ? "VALID" : "REVOKED"),
            '"},',
            '{"trait_type":"tier","value":"',
            Strings.toString(m.tier),
            '"},',
            '{"trait_type":"country","value":"',
            _countryToString(m.countryCode),
            '"},',
            '{"display_type":"date","trait_type":"expiresAt","value":"',
            Strings.toString(m.expiresAt),
            '"}' "]}"
        );
        return string.concat(_BASE_TOKEN_URI, Base64.encode(json));
    }

    /// @dev 禁止创建授权，避免“可转让”的错觉
    function approve(address, uint256) public pure override {
        revert IKycPassNFT__TransferDisabled();
    }

    function setApprovalForAll(address, bool) public pure override {
        revert IKycPassNFT__TransferDisabled();
    }
}
