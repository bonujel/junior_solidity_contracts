# Remix IDE 部署与测试指南

## 📋 目录
1. [准备工作](#准备工作)
2. [部署漏洞演示](#部署漏洞演示)
3. [执行攻击测试](#执行攻击测试)
4. [部署安全版本](#部署安全版本)
5. [验证修复效果](#验证修复效果)
6. [故障排查](#故障排查)

---

## 🚀 准备工作

### 1. 打开 Remix IDE
访问：https://remix.ethereum.org/

### 2. 创建工作空间
1. 点击左侧 "File Explorer"
2. 点击 "+" 创建新工作空间
3. 命名为 `contract-security`

### 3. 上传合约文件
将以下文件复制到 Remix：
- `contracts/VulnerableBank.sol`
- `contracts/ReentrancyAttacker.sol`
- `contracts/SecureBank.sol`（完成修复后）

**方法 1：手动复制粘贴**
1. 在 Remix 中创建新文件
2. 复制本地文件内容粘贴

**方法 2：使用 Remixd（本地文件系统连接）**
```bash
npm install -g @remix-project/remixd
cd /path/to/contract-security
remixd -s . --remix-ide https://remix.ethereum.org
```

---

## 🎯 部署漏洞演示

### 第一步：编译 VulnerableBank

1. **选择编译器**
   - 点击左侧 "Solidity Compiler" 图标
   - 选择版本：`0.8.0` 或更高
   - 启用优化（可选）：200 runs

2. **编译合约**
   - 点击 "Compile VulnerableBank.sol"
   - 确保没有错误（✅ 绿色勾）

### 第二步：部署 VulnerableBank

1. **切换到部署界面**
   - 点击左侧 "Deploy & Run Transactions" 图标

2. **配置环境**
   - **Environment**: 选择 `Remix VM (Shanghai)` 或 `Remix VM (Cancun)`
     - 这是本地测试环境，带有 10 个预置账户
     - 每个账户有 100 ETH 用于测试

3. **部署合约**
   - **Contract**: 选择 `VulnerableBank`
   - 点击 **Deploy** 按钮
   - 等待交易确认

4. **验证部署**
   - 在 "Deployed Contracts" 区域看到 `VulnerableBank at 0x...`
   - 点击展开，查看合约函数

### 第三步：模拟用户存款

1. **切换账户**
   - 在 "Account" 下拉框选择账户（例如：第一个账户）

2. **存款 1 ETH**
   - 在 "VALUE" 输入框输入：`1`
   - 单位选择：`ether`
   - 展开 `VulnerableBank` 合约
   - 点击 `deposit` 按钮

3. **重复存款**
   - 切换到第二个账户
   - 再存入 1 ETH
   - 重复 5-10 次，模拟多个用户

4. **验证余额**
   - 点击 `getContractBalance` 按钮
   - 应显示：`5000000000000000000`（5 ETH）

---

## 💥 执行攻击测试

### 第一步：编译并部署攻击合约

1. **编译 ReentrancyAttacker**
   - 切换到 "Solidity Compiler"
   - 选择 `ReentrancyAttacker.sol`
   - 点击 "Compile"

2. **部署攻击合约**
   - 切换到 "Deploy & Run Transactions"
   - **Contract**: 选择 `ReentrancyAttacker`
   - **部署参数**：
     - `_vulnerableBankAddress`: 复制 `VulnerableBank` 的地址
     - 例如：`0xD4Fc541236927E2EAf8F27606bD7309C1Fc2cbee`
   - 点击 **Deploy**

### 第二步：执行攻击

1. **选择攻击者账户**
   - 切换到一个新账户（例如：账户 #5）

2. **发起攻击**
   - 在 "VALUE" 输入：`1 ether`
   - 展开 `ReentrancyAttacker` 合约
   - 点击 `attack` 按钮（红色）

3. **观察攻击过程**
   - 查看控制台（底部）
   - 应该看到多个 `ReentrancyExecuted` 事件
   - 点击交易查看详细日志

### 第三步：验证攻击结果

1. **检查攻击合约余额**
   - 点击 `getBalance` 按钮
   - 应显示大于 1 ETH（盗取了其他用户的资金）

2. **检查银行余额**
   - 在 `VulnerableBank` 合约点击 `getContractBalance`
   - 应显示 `0` 或非常少（资金被耗尽）

3. **检查受害者余额**
   - 切换回之前存款的账户（例如：账户 #1）
   - 在 `VulnerableBank` 点击 `getBalance`
   - 输入受害者地址（可选）
   - 余额应为 0（资金被盗）

### 第四步：分析攻击日志

点击控制台中的交易，展开 "Logs"：

```
[
  {
    "event": "ReentrancyExecuted",
    "args": {
      "count": 1,
      "balance": "5000000000000000000"
    }
  },
  {
    "event": "ReentrancyExecuted",
    "args": {
      "count": 2,
      "balance": "4000000000000000000"
    }
  },
  ...
]
```

**分析**：
- `count` 显示重入次数
- `balance` 显示每次重入时银行剩余资金
- 攻击持续到银行余额耗尽

---

## ✅ 部署安全版本

### 第一步：完成 SecureBank 修复

在 `SecureBank.sol` 的 `withdraw()` 函数中实现修复逻辑（这是你的任务！）

**提示**：参考 CEI 模式
```solidity
function withdraw() public {
    // 1️⃣ Checks: 检查余额
    uint256 amount = balances[msg.sender];
    require(amount > 0, "Insufficient balance");

    // 2️⃣ Effects: 更新状态（关键！）
    balances[msg.sender] = 0;

    // 3️⃣ Interactions: 发送 ETH
    (bool sent, ) = msg.sender.call{value: amount}("");
    require(sent, "Failed to send Ether");

    emit Withdrawal(msg.sender, amount);
}
```

### 第二步：编译 SecureBank

1. 切换到 "Solidity Compiler"
2. 选择 `SecureBank.sol`
3. 点击 "Compile SecureBank.sol"
4. 确保无错误

### 第三步：部署 SecureBank

1. 切换到 "Deploy & Run Transactions"
2. **Contract**: 选择 `SecureBank`
3. 点击 **Deploy**

### 第四步：模拟用户存款

重复之前的步骤：
- 使用多个账户存入 ETH
- 例如：5 个账户各存 1 ETH

---

## 🛡️ 验证修复效果

### 测试 1：正常提款（应成功）

1. **切换到存款账户**
   - 选择之前存款的账户（例如：账户 #1）

2. **正常提款**
   - 在 `SecureBank` 合约点击 `withdraw`
   - 应成功提取资金

3. **验证余额**
   - 点击 `getBalance`
   - 应显示 `0`（已提取）
   - 检查账户 ETH 余额（应增加）

### 测试 2：尝试攻击（应失败）

1. **部署新的攻击合约**
   - **Contract**: `ReentrancyAttacker`
   - **参数**: `SecureBank` 的地址
   - 点击 **Deploy**

2. **执行攻击**
   - 切换到攻击者账户
   - VALUE: `1 ether`
   - 点击 `attack` 按钮

3. **预期结果**
   - ❌ 交易应该失败或只提取 1 次
   - 查看错误信息："Insufficient balance"

4. **验证安全性**
   - 检查 `SecureBank` 余额
   - 应该只减少 1 ETH（攻击者自己存的）
   - 其他用户资金安全

### 测试 3：边界情况

**测试重复提款（应失败）**
```
1. 用户存入 1 ETH
2. 用户提款 1 ETH（成功）
3. 用户再次提款（应失败："Insufficient balance"）
```

**测试零余额提款（应失败）**
```
1. 用户未存款
2. 直接调用 withdraw（应失败）
```

---

## 🔬 对比测试结果

### VulnerableBank vs SecureBank

| 测试场景 | VulnerableBank | SecureBank |
|----------|----------------|------------|
| 正常提款 | ✅ 成功 | ✅ 成功 |
| 重入攻击 | ❌ 被攻破 | ✅ 防御成功 |
| 重复提款 | ❌ 可能成功 | ✅ 失败（正确） |
| 资金安全 | ❌ 可被盗 | ✅ 安全 |

### Gas 成本对比

在 Remix 查看交易详情：

**VulnerableBank.withdraw()**
- Gas used: ~50,000（单次）
- 攻击时：~500,000+（重入多次）

**SecureBank.withdraw()**
- Gas used: ~50,000（单次）
- 攻击失败：~30,000（revert）

---

## 🐛 故障排查

### 问题 1：编译错误 "Source file requires different compiler version"

**解决方案**：
```solidity
// 修改为范围版本
pragma solidity ^0.8.0;  // ✅ 允许 0.8.x
// 而非
pragma solidity 0.8.0;   // ❌ 严格要求 0.8.0
```

### 问题 2：部署时找不到合约

**解决方案**：
1. 确保文件已保存
2. 重新编译合约
3. 刷新 Remix 页面

### 问题 3：攻击合约部署失败 "Invalid address"

**解决方案**：
1. 确保 `VulnerableBank` 已部署
2. 复制完整地址（带 `0x` 前缀）
3. 地址格式：`0xD4Fc541236927E2EAf8F27606bD7309C1Fc2cbee`

### 问题 4：交易失败 "Out of gas"

**解决方案**：
1. 增加 Gas Limit
   - 在 "Deploy & Run" 界面
   - "Gas limit": 设置为 `3000000`

### 问题 5：攻击没有成功（VulnerableBank）

**可能原因**：
1. 银行余额不足 1 ETH
   - 先存入更多 ETH
2. 使用了错误的合约版本
   - 确保使用 `VulnerableBank`，不是 `SecureBank`

### 问题 6：SecureBank 攻击成功了（不应该）

**检查清单**：
1. ❌ 是否忘记更新余额？
   ```solidity
   balances[msg.sender] = 0;  // 必须在 call 之前
   ```
2. ❌ 是否先转账再更新？
   ```solidity
   // 错误顺序
   call{value: amount}("");  // ❌
   balances[msg.sender] = 0; // ❌ 太晚了
   ```

---

## 📊 完整测试清单

### ✅ VulnerableBank 测试
- [ ] 部署合约
- [ ] 多个账户存款（至少 5 个，每个 1 ETH）
- [ ] 查询合约余额（应为 5+ ETH）
- [ ] 部署攻击合约
- [ ] 执行攻击
- [ ] 验证攻击成功（合约余额接近 0）
- [ ] 检查日志中的重入事件

### ✅ SecureBank 测试
- [ ] 完成代码修复
- [ ] 编译无错误
- [ ] 部署合约
- [ ] 多个账户存款
- [ ] 正常提款测试（应成功）
- [ ] 部署攻击合约（指向 SecureBank）
- [ ] 执行攻击
- [ ] 验证攻击失败
- [ ] 确认其他用户资金安全
- [ ] 测试边界情况（重复提款、零余额提款）

### ✅ 额外挑战
- [ ] 实现 ReentrancyGuard 版本
- [ ] 对比三种实现的 Gas 成本
- [ ] 编写自动化测试脚本（JavaScript）
- [ ] 部署到测试网（Sepolia）

---

## 🎓 学习要点总结

通过完成这个实验，你应该掌握：

1. **重入攻击原理**
   - 外部调用的风险
   - fallback/receive 函数的作用
   - 状态更新时机的重要性

2. **CEI 模式**
   - Checks（检查）
   - Effects（状态更新）
   - Interactions（外部交互）
   - 执行顺序至关重要

3. **Remix IDE 使用**
   - 合约编译和部署
   - 交易调试
   - 事件日志分析
   - 多账户测试

4. **安全思维**
   - 始终假设外部调用不可信
   - 先更新状态，再交互
   - 多层防护（CEI + ReentrancyGuard）
   - 全面测试（正常 + 攻击 + 边界）

---

## 📚 下一步学习

1. **深入学习其他漏洞**
   - 整数溢出/下溢
   - 访问控制缺失
   - 前置交易
   - 预言机操纵

2. **学习测试框架**
   - Hardhat + Ethers.js
   - Foundry (Forge)
   - 模糊测试（Fuzzing）

3. **审计实践**
   - 阅读真实审计报告
   - 参与 Code4rena、Sherlock 等平台
   - 学习使用 Slither、Mythril 等工具

4. **挑战平台**
   - Ethernaut
   - Damn Vulnerable DeFi
   - Capture the Ether

---

**祝你学习顺利！安全永远是第一位的！🔒**
