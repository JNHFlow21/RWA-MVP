很好，5.2 开工的正确“下笔顺序”是这样的：

先把份额代币（ShareToken / VaultToken）做出来 → 再写 Vault（先 ETH 版）→ 最后再扩到 ERC-20 版并接 USDCMock。

原因：Vault 依赖份额代币的 mint/burn，而代币不依赖 Vault 的业务逻辑。把依赖“根”先定好，你的 Vault 代码和测试会更顺畅。

下面给你一份从零到一的实施清单（不写实现代码，只给到“该有哪些函数/错误/状态”的层级），你照着把文件和测试骨架建起来即可。

⸻

① 先做 ShareToken（份额 ERC-20）

目标：标准 ERC-20，但只有 Vault 合约可以铸/销。小数位和资产保持一致（ETH=18；以后接 USDC=6）。

A. 需要的“对外能力”（函数签名层面）
	•	name() / symbol() / decimals()（只读）
	•	totalSupply()/balanceOf()/transfer()/transferFrom()/approve()/allowance()（ERC-20 常规）
	•	新增（仅 Vault 可调）：
	•	mint(address to, uint256 amount)
	•	burn(address from, uint256 amount)
	•	治理/绑定：
	•	vault() -> address（谁是唯一的铸/销者）
	•	setVault(address v)（只能设置一次，或者在构造时注入）

B. 状态 & 约束（不变量）
	•	address private vault;
	•	uint8 private immutable _decimals;
	•	不变量：
	•	只有 msg.sender == vault 才能 mint/burn
	•	setVault 只能成功一次（或构造即定死）

C. 错误/事件（非必须，但建议）
	•	error OnlyVault();
	•	error VaultAlreadySet();

D. 你要写的测试（先写断言，再补实现）
	•	非 vault 调 mint/burn → revert OnlyVault
	•	绑定一次后的二次绑定 → revert VaultAlreadySet
	•	decimals() 返回正确（ETH 版 18）
	•	正常转账/授权不受影响

落地建议：文件 src/ShareToken.sol；如果你喜欢接口先行，也可加一个最小接口 IShareToken（继承 IERC20 并补 mint/burn/vault()），但这一步不是硬性要求。

⸻

② 再做 SimpleVault（先 ETH 版本）

目标：持有有效 KYC 的用户可以 depositETH()，按 1:1 获得份额；withdraw(shares) 销份额并取回同量 ETH。

A. 需要的“对外能力”（函数签名层面）
	•	只读：
	•	kyc() -> address
	•	share() -> address
	•	asset() -> address（ETH 版可返回 address(0)）
	•	totalAssets() -> uint256（ETH 版 = address(this).balance）
	•	写：
	•	depositETH() payable
	•	前置：调用 KycPass.hasValidPass(msg.sender) 为真
	•	效果：收 msg.value、share.mint(msg.sender, msg.value)
	•	事件：Deposit(msg.sender, assets=msg.value, shares=msg.value)
	•	withdraw(uint256 shares)
	•	效果：share.burn(msg.sender, shares)，向 msg.sender 发送 shares wei
	•	事件：Withdraw(msg.sender, assets=shares, shares=shares)

B. 约束（不变量）
	•	准入：无证/过期用户 depositETH() 必须 revert（MVP 建议：withdraw 不做 KYC 限制）
	•	会计：在 1:1 模式下始终有
share.totalSupply() == totalAssets()
	•	安全：
	•	withdraw 加 nonReentrant
	•	Checks-Effects-Interactions：先 burn 份额，再转账 ETH
	•	对 0 值输入（0 ETH / 0 shares）直接 revert（省掉奇怪边界）

C. 错误/事件
	•	error NotKycQualified();
	•	error InvalidAmount();
	•	事件：Deposit(user, assets, shares)、Withdraw(user, assets, shares)

D. 你要写的测试（ETH 路径）
	•	KYC Gate：无证调用 depositETH() → revert NotKycQualified
	•	Happy Path：有证 depositETH{value: 1 ether} →
share.balanceOf(user)=1e18；totalAssets=1e18
	•	Withdraw：withdraw(0.4e18) → 份额减；用户 ETH +0.4e18；totalAssets 同步减少
	•	恒等式：各步骤都断言 share.totalSupply == totalAssets
	•	边界：0 值、余额不足等都应 revert
	•	权限：用户无法直接在 ShareToken 上 mint/burn

⸻

③（之后）再扩到 ERC-20 资产路径 + USDCMock

当 ETH 路径绿了，再做：
	•	在 Vault 里加入 asset（ERC-20 地址），新增：
	•	deposit(uint256 assets)：asset.safeTransferFrom(...) 后 mint 同量份额
	•	withdraw(uint256 shares)：burn 后 asset.safeTransfer(...)
	•	totalAssets() 改为 asset.balanceOf(this)
	•	小数位策略：MVP 阶段让 share.decimals == asset.decimals（USDC=6），保持 1:1
	•	写上 USDCMock（6 decimals，owner 可 mint 即可）并补测试

⸻

④ 代码落地的推荐顺序（commit 粒度）
	1.	feat(share): scaffold ShareToken (onlyVault mint/burn, decimals, setVault-once)
	•	同时写 test/ShareToken.t.sol 覆盖 onlyVault/decimals/绑定一次
	2.	feat(vault): scaffold SimpleVault (ETH) + events + errors
	•	test/SimpleVaultETH.t.sol 覆盖 KYC、1:1、withdraw、安全与边界
	3.	chore(script): DeployAll.s.sol 绑定 share.vault = vault，并跑一次 depositETH/withdraw 演示
	4.	（其后）feat(vault): add ERC20 asset path + feat(mock): add USDCMock + 对应测试

⸻

⑤ 要不要“先定义接口再实现”？
	•	如果你喜欢“规格驱动”：
是的，像 5.1 一样先在 src/interfaces/ 放两份最小接口：
	•	IShareToken : IERC20 { mint; burn; vault(); }
	•	ISimpleVault { depositETH; withdraw; totalAssets; kyc; share; asset; }
这样测试可以“面向接口”写，换实现也方便。
	•	如果你更在意速度：
也可以直接实现 ShareToken.sol 和 SimpleVault.sol，但务必先把上面的函数列表、错误、事件记到 README/注释（当作“口头接口”）。测试照这个口径写即可。

两条路都行。关键是：先定好 ShareToken 的外形（onlyVault + decimals），因为 Vault 的代码要调用它的 mint/burn。

⸻

⑥ 开工前 10 分钟自检
	•	KYC 合约地址拿得到（你 5.1 已完成）
	•	决定 ShareToken 的绑定方式：构造传 vault 或 setVault() 只允一次
	•	写好测试标题（AAA/GWT 注释），先把断言列出来
	•	在 README 的 5.2 段补三条“不变量”：准入/会计恒等/onlyVault

⸻

如果你愿意，我可以把 ShareToken 的 NatSpec 接口注释 和 SimpleVault(ETH) 的接口注释按你项目的风格写好（仍不含实现），你直接复制到文件里就能 forge build，然后按上面的测试清单一点点把红灯变绿。需要吗？我可以现在就给。