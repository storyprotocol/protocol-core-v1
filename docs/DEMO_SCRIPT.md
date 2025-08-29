# 🎯 Story Protocol 安全测试演示脚本

## 开场白

大家好！今天演示一下 Story Protocol 的安全测试体系。

智能合约最大的风险就是代码 bug，一旦出现问题，用户资金可能全部损失。所以我们建立了三层防护的测试体系。

主要分为三层：
1. **功能测试** - 确保基本功能正常工作
2. **安全扫描** - 检测常见的安全漏洞
3. **形式化验证** - 数学证明核心逻辑的正确性

接下来逐一演示每个部分。

---

## Part 1: 功能测试 - 真实网络验证

首先是功能测试，使用 Hardhat 在 aeneid 测试网上运行。

### 测试目标

Story Protocol 的权限系统：确保只有 IP 的所有者能操作自己的账户，其他人无法访问。

这个看似简单的逻辑实际涉及多个合约之间的交互，需要验证整个调用链的正确性。

### 测试场景1：正常权限操作

测试用户为自己的 IP 设置权限的正常流程。

```bash
npx hardhat test test/hardhat/e2e/ipaccount/*.ts \
  --network aeneid \
  --grep "IP Owner execute AccessController module"
```

测试代码如下：

```typescript
it("IP Owner execute AccessController module", async function () {
  // 1. 先在真实区块链上创建一个 IP 账户
  const { tokenId: tokenId1, ipId: ipId1 } = await mintNFTAndRegisterIPA(this.user1, this.user1);
  
  // 2. 拿到这个 IP 账户的合约
  const ipAccount1Contract = await hre.ethers.getContractAt("IPAccountImpl", ipId1, this.user1);
  
  // 3. 尝试设置权限
  await expect(
    ipAccount1Contract.execute(
      AccessController,  // 调用权限控制合约
      0,                // 不发 ETH
      this.accessController.interface.encodeFunctionData("setPermission", [
        ipId1,           // 给自己的 IP
        ipId1,           // 设置权限
        LicensingModule, // 许可模块
        this.licensingModule.interface.getFunction("attachLicenseTerms").selector,
        1               // 权限级别
      ])
    )
  ).not.to.be.rejectedWith(Error);  // 期望成功
});
```

这个测试在真实区块链上运行，创建实际的 NFT 和 IP 账户，验证权限设置功能。通过表示权限系统基本功能正常。

### 测试场景2：越权攻击防护

除了正常功能，还需要测试安全边界。验证用户 A 是否能操作用户 B 的 IP。

```typescript
it("Non-IP Owner execute AccessController module", async function () {
  // 1. 创建用户1的 IP 账户
  const { tokenId: tokenId1 } = await mintNFTAndRegisterIPA(this.user1, this.user1);
  const ipAccount1 = await this.ipAssetRegistry.ipAccount(this.chainId, MockERC721, tokenId1, this.user1);
  
  // 2. 创建用户2的 IP 账户
  const { tokenId: tokenId2, ipId: ipId2 } = await mintNFTAndRegisterIPA(this.user2, this.user2);
  const ipAccount2Contract = await hre.ethers.getContractAt("IPAccountImpl", ipId2, this.user2);
  
  // 3. 用户2试图操作用户1的账户 - 这应该被拒绝！
  await expect(
    ipAccount2Contract.execute(
      AccessController,
      0,
      this.accessController.interface.encodeFunctionData("setPermission", [
        ipAccount1,  // 注意这里！试图操作别人的账户
        ipAccount1,
        LicensingModule,
        this.licensingModule.interface.getFunction("attachLicenseTerms").selector,
        1
      ])
    )
  ).to.be.revertedWithCustomError(this.errors, "AccessController__CallerIsNotIPAccountOrOwner");
});
```

这个测试应该失败，并且抛出特定的错误。如果真的失败了，说明我们的权限边界是清楚的，坏人偷不了你的 IP。

### 结果

如果两个测试都通过了，就说明：
- 正常功能可以用 ✅
- 攻击会被拦住 ✅
- 整个权限系统在真实环境下工作正常 ✅

---

## Part 2: 安全扫描 - 快速找漏洞

功能测试只能测试你想到的场景，但还有很多你想不到的安全问题。这时候就需要工具来帮忙了。

### Slither - 智能合约的杀毒软件

Slither 就像个杀毒软件，几秒钟就能扫出你代码里的各种常见问题。

```bash
make slither
npm run slither:html
```

### 它能找到什么？

Slither 有 70 多种检查规则，会按严重程度分类：

**🔴 高危问题**：重入攻击、整数溢出等，必须修复  
**🟡 中危问题**：外部调用风险、Gas 优化等，建议修复  
**🔵 低危问题**：命名规范、代码质量等，可选修复

### 我们项目的扫描结果

```
✅ 无高危问题
🟡 几个中危：重入攻击风险（已评估，影响有限）
🔵 一些低危：命名规范建议
```

这个结果说明我们的代码质量还不错，没有明显的安全漏洞。

### 为什么用它？

- **快**：几秒钟搞定
- **全**：70+ 种问题都能找到
- **便宜**：免费的，而且不用部署
- **自动化**：可以集成到 CI，每次提交自动检查

这是我们的第一道防线，把明显的坑先找出来。

---

## Part 3: 数学证明 - 终极保险

前面两步都是基于经验和启发式的方法，但对于核心的安全属性，我们还需要更严格的保证。这就是 Certora 的作用了。

### 普通测试 vs 数学证明

让我先解释一下区别：

**普通测试**：
```typescript
it("Owner can execute", async () => {
  const owner = "0x1234...";  // 具体地址
  const target = "0x5678..."; // 具体合约
  const data = "0xabcd...";   // 具体数据
  
  await ipAccount.execute(target, 0, data);
  expect(result).to.be.successful;
});
```

这只是测试了一个具体的例子。如果 owner 是别的地址呢？如果 target 是别的合约呢？你不可能把所有情况都测试一遍。

**Certora 数学证明**：
```cvl
rule ownerCanExecute() {
    env e;
    address to;      // 任意地址！
    uint256 value;   // 任意金额！
    bytes data;      // 任意数据！
    
    require(e.msg.sender == owner(e));  // 前提：调用者是 owner
    
    execute@withrevert(e, to, value, data);
    
    assert !lastReverted;  // 结论：永远不会失败
}
```

这是在数学上证明：对于所有可能的输入组合，只要调用者是 owner，execute 函数就不会失败。

### 覆盖度的差别

```
普通测试：● ● ●          (测试几个点)
Certora： ██████████████ (覆盖所有可能)
```

### 我们的验证

```bash
npm run certora:verify
```

我们写了两个规则：

**规则1：非 owner 不能执行**
```cvl
rule onlyOwnerCanExecute() {
    env e;
    address to;
    uint256 value;
    bytes data;
    
    address currentOwner = owner(e);
    require(e.msg.sender != currentOwner);  // 前提：不是 owner
    
    execute@withrevert(e, to, value, data);
    
    assert lastReverted, "Non-owner should not be able to execute";
}
```

**规则2：owner 总是能执行**
```cvl
rule ownerCanExecute() {
    env e;
    address to;
    uint256 value;
    bytes data;
    
    address currentOwner = owner(e);
    require(e.msg.sender == currentOwner);  // 前提：是 owner
    
    execute@withrevert(e, to, value, data);
    
    assert !lastReverted, "Owner should be able to execute valid transactions";
}
```

**验证结果**：
```
✅ onlyOwnerCanExecute: PASSED  
✅ ownerCanExecute: PASSED
```

这意味着我们在数学上证明了：只有 owner 能操作自己的 IP 账户。

### 坦白说，Certora 不好用

**学习成本高**：需要学习 CVL 语言  
**调试复杂**：错误信息不够友好  
**时间成本高**：一个简单规则可能调试几天  
**工具限制**：复杂合约需要写 Harness 简化

但对于管理大量资金的 DeFi 协议来说，这种数学级别的保证是值得的。

---

## 总结：三层防护

我们的安全测试体系就是这样：

**🧪 Hardhat 测试**：快速验证功能，确保基本能用  
**🔍 Slither 扫描**：自动发现常见问题，防止低级错误  
**🔬 Certora 证明**：数学验证核心属性，提供最高级别保证

### 成本效益

- **Hardhat**：便宜好用，开发必备
- **Slither**：几乎免费，性价比很高
- **Certora**：贵但值得，只用于最核心的逻辑

### 最终效果

三层防护加起来，我们可以说 Story Protocol 达到了工业级的安全标准：

- 功能正确 ✅
- 安全可靠 ✅  
- 数学严谨 ✅

这就是为什么用户可以放心地把他们的 IP 资产托付给我们。

---

## Q&A

**Q: 为什么不只用一种测试方法？**  
A: 就像体检一样，血常规发现不了骨折，X 光看不到血液问题。不同的工具有不同的强项，组合起来才能全面覆盖。

**Q: Certora 这么难用，真的值得吗？**  
A: 对于管理用户资金的项目来说，数学级的安全保证不是奢侈品，是必需品。一次攻击的损失可能远超开发成本。

**Q: 普通项目也需要这么复杂的测试吗？**  
A: 看你的项目管理多少钱。如果只是个 demo，Hardhat + Slither 就够了。但如果用户会把真金白银放进来，那就不能省这个钱。

**Q: 这套体系的维护成本高吗？**  
A: Hardhat 和 Slither 几乎不需要维护，Certora 确实需要专门的团队。但相比被黑客攻击的损失，这点投入真的不算什么。

---

**结语**：安全不是一次性的工作，而是一个持续的过程。Story Protocol 选择了这套三层防护体系，就是为了给用户最大的安心。
