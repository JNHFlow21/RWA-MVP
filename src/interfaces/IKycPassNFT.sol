// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IKycPassNFT - RWA KYC 通行证（SBT 风格）接口
/// @notice 通过/吊销“投资资格”通行证；供金库在存取款前做 on-chain KYC 校验。
/// @dev 建议基于 ERC-721 实现并禁止任何形式的转让（SBT 语义）；
////     仅保留铸造/吊销/查询。支持 EIP-165。
interface IKycPassNFT {
    // ----------------------- Types -----------------------

    /// @notice 通行证轻量元数据（不上链任何敏感 KYC 材料）
    /// @param tier 投资者分层（0=零售，1=专业，2=受限…按需定义）
    /// @param expiresAt 过期时间（unix 秒；0 表示永久）
    /// @param countryCode ISO 国家编码（如 "CN" -> bytes2 / bytes32 存储）
    struct PassMeta {
        uint8 tier;
        uint64 expiresAt;
        bytes32 countryCode;
    }

    // ----------------------- Events -----------------------

    /// @notice 成功签发一张通行证
    /// @param to 接收地址
    /// @param tokenId 通行证 tokenId
    /// @param meta 轻量元数据
    event PassIssued(address indexed to, uint256 indexed tokenId, PassMeta meta);

    /// @notice 成功吊销一张通行证
    /// @param tokenId 被吊销的通行证 tokenId
    event PassRevoked(uint256 indexed tokenId);

    // ----------------------- Errors -----------------------

    /// @notice 非授权（非管理员/发行人）调用受限函数
    error NotAuthorized();

    /// @notice 通行证不可转让（SBT 语义）
    error TransferDisabled();

    /// @notice 通行证不存在或已失效
    error InvalidOrExpiredPass();

    // ----------------------- Views -----------------------

    /// @notice 查询地址是否持有有效通行证
    /// @param user 待检查的钱包地址
    /// @return ok 是否有效
    /// @return meta 通行证轻量元数据（若无效，字段可返回默认值）
    function hasValidPass(address user) external view returns (bool ok, PassMeta memory meta);

    /// @notice 返回某通行证的轻量元数据
    function passMetaOf(uint256 tokenId) external view returns (PassMeta memory);

    /// @notice EIP-165 支持（若实现为 ERC-721）
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // ----------------------- Mutations -----------------------

    /// @notice 签发通行证（仅 KYC 发行者/管理员）
    /// @dev 实现中应：1) 生成并绑定 tokenId；2) 记录 meta；3) 禁止转让。
    /// @param to 接收地址
    /// @param meta 轻量元数据
    /// @return tokenId 新铸通行证 ID
    /// @custom:access only-issuer-or-admin
    /// @custom:events PassIssued
    function mintPass(address to, PassMeta calldata meta) external returns (uint256 tokenId);

    /// @notice 吊销通行证（仅 KYC 发行者/管理员）
    /// @dev 可选择 burn 该 tokenId；被吊销后 hasValidPass 应返回 false。
    /// @param tokenId 待吊销通行证
    /// @custom:access only-issuer-or-admin
    /// @custom:events PassRevoked
    function revokePass(uint256 tokenId) external;
}