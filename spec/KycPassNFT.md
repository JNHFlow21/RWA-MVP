好，5.1 的目标是把 **KYC 通行证（SBT 风格的 ERC-721）从 0 做到能跑：签发 / 吊销 / 校验有效性，并且禁止任何用户↔用户转让**。下面是一份**纯流程的执行清单**（无代码），从准备 → 实现 → 自测 → 集成，完成后你就能进入 5.2。



------





## **A. 结果长什么样（完成后的能力）**





- 合约：KycPassNFT

- 你能做：

  

  1. 管理员/发行者给地址**签发**通行证；
  2. 管理员/发行者**吊销**通行证；
  3. 金库等合约可通过 hasValidPass(address) **校验资格**；
  4. **禁止转让**（SBT 语义）：任何 transferFrom/safeTransferFrom/approve 都会被拒；
  5. 有**事件日志**：PassIssued / PassRevoked，便于前端与链下统计。

  





> 达成条件：测试能证明“无证不可存款”“证件过期/吊销后不可存款”“不可转让”。



------





## **B. 开工前 5 分钟检查**





1. **OZ 版本**：确认 openzeppelin-contracts 为 v5.x（你贴的 ERC721 是 v5.4.0）；

2. **接口文件**：src/interfaces/IKycPassNFT.sol 已就位（你之前拷过模板）；

3. **角色设计**（写进 README 决策区）：

   

   - DEFAULT_ADMIN_ROLE：全局管理员；
   - KYC_ISSUER_ROLE：签发与吊销通行证；
   - 规则：DEFAULT_ADMIN_ROLE 初始授予部署者；可额外授予其他发行者。

   

4. **一地址一证**：明确“一个地址同时最多持一张”；换证需先吊销再签发。

5. **元数据**：仅上链轻量字段（tier / expiresAt / countryCode），**不要上链身份证明材料**。





------





## **C. 实现顺序（逐项打勾，写完一个小步就** 

## **forge build**

## **）**





> **不写代码解释**，只告诉你“要做什么”。





1. **定义角色常量与事件/错误**

   

   - 角色：DEFAULT_ADMIN_ROLE（已有）、KYC_ISSUER_ROLE；
   - 事件：PassIssued(to, tokenId, meta)、PassRevoked(tokenId)；
   - 错误：NotAuthorized()、TransferDisabled()、InvalidOrExpiredPass()、AlreadyHasPass(address) / NonexistentPass(uint256)（名称按你习惯）。

   

2. **存储结构**

   

   - passOf[address] -> tokenId（0 表示无证，保证一地址一证）；
   - passMetaOf[tokenId] -> PassMeta{ tier:uint8, expiresAt:uint64, countryCode:bytes32 }；
   - _tokenIdCounter 从 1 开始（便于用 0 表示“无”）；
   - （可选）_baseTokenURI 用于 tokenURI 拼接。

   

3. **构造函数**

   

   - 设定 name/symbol；
   - _grantRole(DEFAULT_ADMIN_ROLE, admin)；
   - _grantRole(KYC_ISSUER_ROLE, admin)；
   - （可选）_setRoleAdmin(KYC_ISSUER_ROLE, DEFAULT_ADMIN_ROLE) 保持默认管理关系。

   

4. **视图函数**

   

   - hasValidPass(address)：

     

     - 读 passOf[user]；若为 0 返回 false；
     - 取 passMetaOf[tokenId]，如果 expiresAt == 0 或 now <= expiresAt 则 ok=true；
     - 返回 (ok, meta)；

     

   - passMetaOf(tokenId)：token 存在时返回元数据，否则抛不存在错误；

   - supportsInterface：合并 ERC721 / AccessControl / IKycPassNFT；

   - （可选）_baseURI()：返回你设置的基础链接。

   

5. **写方法（签发/吊销）**

   

   - mintPass(to, meta)：

     

     - 仅 DEFAULT_ADMIN_ROLE 或 KYC_ISSUER_ROLE；
     - passOf[to] == 0；
     - tokenId = ++_tokenIdCounter；写入 passOf[to] 与 passMetaOf[tokenId]；
     - _safeMint(to, tokenId)；emit PassIssued；

     

   - revokePass(tokenId)：

     

     - 仅 DEFAULT_ADMIN_ROLE 或 KYC_ISSUER_ROLE；
     - 查 owner 存在；delete passOf[owner]、delete passMetaOf[tokenId]；
     - _burn(tokenId)；emit PassRevoked。

     

   

6. **SBT 语义（禁止转让与授权）**

   

   - **统一拦截点**：覆盖 ERC721 的 _update(to, tokenId, auth)：

     

     - 若 from != 0 && to != 0（用户→用户转移）→ revert TransferDisabled()；
     - 允许 mint（from=0）与 burn（to=0）；
     - 其余逻辑交给父类；

     

   - **禁用授权**：覆盖 approve 与 setApprovalForAll 直接 revert TransferDisabled()（避免“可授权=可转让”的错觉）。

   

7. **管理员便捷操作（可选）**

   

   - setBaseURI(newURI)：仅管理员；
   - grantRole/revokeRole 的外层封装（可不写，直接用 OZ 的公共函数）。

   





> 至此，合约功能完成。forge build 应通过。



------





## **D. 自测计划（Foundry，用例标题与断言点；写完一个过一个）**





> 用 Given / When / Then 方式先写测试注释和断言，再补实现；每次只测一件事。





1. **签发成功**

   

   - Given：发行者地址 A；
   - When：mintPass(user, meta)；
   - Then：passOf[user] != 0，hasValidPass(user).ok == true，事件 PassIssued 参数匹配。

   

2. **重复签发被拒**

   

   - Given：用户已持证；
   - When：再次 mintPass；
   - Then：revert（AlreadyHasPass）。

   

3. **过期逻辑**

   

   - Given：expiresAt = now + 1；
   - When：时间推进超过过期；
   - Then：hasValidPass(user).ok == false。

   

4. **吊销**

   

   - Given：用户已持证；
   - When：revokePass(tokenId)；
   - Then：passOf[user] == 0，hasValidPass(user).ok == false，事件 PassRevoked。

   

5. **不可转让**

   

   - Given：用户持证；
   - When：transferFrom(user, other, tokenId) 或 safeTransferFrom；
   - Then：revert（TransferDisabled）。

   

6. **禁用授权**

   

   - When：approve(other, tokenId) 或 setApprovalForAll；
   - Then：revert（TransferDisabled）。

   

7. **权限**

   

   - When：非发行者/管理员调用 mintPass / revokePass；
   - Then：revert（AccessControlUnauthorizedAccount）。

   





------





## **E. 脚本/演示串联（把 5.1 接入你的脚本骨架）**





1. **DeployAll.s.sol**

   

   - 部署 KycPassNFT(name,symbol,admin)；
   - grantRole(KYC_ISSUER_ROLE, <issuerAddr>)（可选；默认 admin 已有）；
   - 日志打印合约地址与角色授予结果。

   

2. **IssuePass.s.sol**

   

   - 读取部署出的 KycPassNFT 地址；
   - 用发行者账户 mintPass(USER, PassMeta{...})；
   - 打印 tokenId 与 hasValidPass(USER)。

   

3. **本地演示顺序**

   

   - anvil 启动本地链 → 跑 DeployAll → 跑 IssuePass → 尝试 safeTransferFrom（预期失败）→ 用 cast call 看 hasValidPass(USER)。

   





------





## **F. 文档与仓库更新（完成就 commit）**





- 在 README 的“产品决策”处写清：

  

  - 一地址一证；
  - SBT 语义；
  - 轻量元数据字段；
  - 角色与谁能干什么（表格列出）。

  

- 在接口头部（NatSpec）补齐：事件、错误、访问控制、SBT 说明。

- 添加“测试清单与通过截图/日志”。





------





## **G. 验收标准（Definition of Done）**





- ✔ **功能**：mintPass/revokePass/hasValidPass 正常，SBT 禁转/禁授权；
- ✔ **权限**：非授权地址无法签发/吊销；
- ✔ **事件**：PassIssued / PassRevoked 参数与状态一致；
- ✔ **测试**：上述 7 条用例全部通过；
- ✔ **脚本**：DeployAll + IssuePass 跑通；
- ✔ **文档**：README 决策/流程/角色表已更新。





------





## **H. 常见坑（提前规避）**





- **忘记一地址一证**：签发前检查 passOf[to] == 0；吊销时清干净映射。
- **SBT 拦截点放错**：务必在 **_update** 里拦；这是 v5 的统一转移入口。
- **授权没禁**：只拦了转移没禁 approve/setApprovalForAll，会让前端产生“可转”的错觉。
- **过期判断**：expiresAt == 0 代表永久有效；比较用 <=。
- **角色授予**：部署脚本里记得把发行者角色授予给测试账户，不然签发会因权限失败。





------



> 就这些。你照着 C+D+E 执行，一条条勾掉，很快就能把 5.1 打通。完成后告诉我测试里有什么红/绿，我们再进入 **5.2（VaultToken：份额 ERC-20，仅金库可铸/销）** 的步骤清单。