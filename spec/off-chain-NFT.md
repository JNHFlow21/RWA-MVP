# Off-Chain NFT 参考实现

> 图片与 JSON 存储在 **IPFS / Pinata**，合约仅保存 `tokenURI`。

## 1. 继承 ERC721

与链上版本一致，继承自 `ERC721` 并实现必要权限控制。

## 2. 实现 `mint()` 与重写 `tokenURI()`

在 `mint()` 时直接写入外部获取的 `tokenURI`，`tokenURI()` 返回该值即可。

## 3. 上传图片至 IPFS

1. 使用 Pinata、web3.storage 等服务上传图片。  
2. 获取 CID，例如：

```
ipfs://QmQiQk4HjgyffQuywvDrdu5UD5wHEzgqJ17UFwJCLUCbCL
```

> 该链接即为 `image` 字段的值。

## 4. 编写并上传 Metadata JSON

```json
{
  "name": "Luffy #1",
  "description": "A soulbound KYC pass featuring Luffy. Example NFT metadata.",
  "image": "ipfs://QmQiQk4HjgyffQuywvDrdu5UD5wHEzgqJ17UFwJCLUCbCL"
}
```

1. 将 JSON 文件上传至 IPFS，得到新的 CID，例如：

```
ipfs://QmV2WHpdB9FcEApEqn1yAgLo7UovXG7qZjUNmMAjsEonH8
```

2. 该链接即 `tokenURI`，在 `mint()` 时传入。

## 5. Mint 并在钱包查看

1. 调用 `mint(address to, string calldata tokenURI)`。  
2. 在钱包输入合约地址与 `tokenId` 即可查看 NFT。  
3. 若图片延迟显示，稍等片刻或再次打开钱包。

---

**完成！** 这样就打造了一个依赖 IPFS 的 Off-Chain NFT。🚀
