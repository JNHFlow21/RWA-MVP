# On-Chain NFT 参考实现

> 通过完全链上存储 SVG 与 JSON，实现无需外部依赖的动态 **Soulbound KYC Pass**。

## 1. 继承 ERC721

合约继承自 OpenZeppelin `ERC721`，并根据需要加入 `AccessControl` 等权限控制。

## 2. 定义元数据常量

```solidity
string private constant _BASE_IMAGE_URI = "data:image/svg+xml;base64,";
string private constant _BASE_TOKEN_URI = "data:application/json;base64,";
```

## 3. 动态状态变量与构造函数

为不同状态预留 SVG 模板字符串，并在构造函数中注入实际的 SVG 代码：

```solidity
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

    svgValid  = svgValid_;
    svgRevoke = svgRevoke_;
}
```

## 4. 重写 `tokenURI`

`tokenURI` 根据持证人状态（有效 / 已吊销）动态选择 SVG，并拼装完整的 Base64 JSON：

```solidity
// ---------- tokenURI：动态选择模板并组装 JSON ----------
// svg -> base64(svg) -> _BASE_IMAGE_URI + base64(svg)
//   -> json -> base64(json) -> _BASE_TOKEN_URI + base64(json) = tokenURI
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    address holder = _requireOwned(tokenId);
    (bool ok, PassMeta memory m) = hasValidPass(holder);

    // 1) 选择模板并生成 data:image
    string memory svg = ok ? svgValid : svgRevoke;
    string memory imgURI = string.concat(_BASE_IMAGE_URI, Base64.encode(bytes(svg)));

    // 2) 组装 metadata（最少包含 name / description / image）
    bytes memory json = abi.encodePacked(
        '{"name":"KYC Pass #',       Strings.toString(tokenId), '",',
        '"description":"Soulbound KYC pass (on-chain SVG via template).",',
        '"image":"',                imgURI, '",',
        '"attributes":[',
            '{"trait_type":"status","value":"',  (ok ? "VALID" : "REVOKED"), '"},',
            '{"trait_type":"tier","value":"',    Strings.toString(m.tier),  '"},',
            '{"trait_type":"country","value":"', _countryToString(m.countryCode), '"},',
            '{"display_type":"date","trait_type":"expiresAt","value":"', Strings.toString(m.expiresAt), '"}' ,
        ']}'
    );

    return string.concat(_BASE_TOKEN_URI, Base64.encode(json));
}
```

## 5. 部署脚本：读取 SVG 并部署

```solidity
string svgValid  = vm.readFile("image/valid.svg");
string svgRevoke = vm.readFile("image/revoke.svg");

deployConfig.pass = new KycPassNFT("Pass", "PASS", admin, svgValid, svgRevoke);
```

确保在 `foundry.toml` 中开放读取权限，并启用 FFI：

```toml
fs_permissions = [
    { access = "read", path = "./broadcast" },
    { access = "read", path = "./reports" },
    { access = "read", path = "./image/" },
]
ffi = true
```

## 6. Mint 及钱包显示

1. 调用 `mintPass(address to, PassMeta calldata meta)` 铸造 Pass。  
2. 在钱包（如 MetaMask）切换至对应网络，添加合约地址并填写 `tokenId`。  
3. 图片若未立即加载，请稍后刷新——Base64 数据较大时 MetaMask 可能缓存延迟。

---

**至此，链上动态 NFT 已完成！** 🎉
