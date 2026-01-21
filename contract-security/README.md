# 🔐 Solidity 智能合约安全学习项目

> 通过实战学习重入攻击（Reentrancy Attack）及其防御方法

## 📖 项目简介

这是一个教育性的 Solidity 安全学习项目，专注于最危险的智能合约漏洞之一：**重入攻击**。通过实际编写和部署存在漏洞的合约、攻击合约以及安全修复版本，你将深入理解这类漏洞的原理和防御方法。

## 🎯 学习目标

通过本项目，你将学习：

1. ✅ **重入攻击原理**：理解 The DAO 事件背后的技术细节
2. ✅ **CEI 模式**：掌握 Checks-Effects-Interactions 安全模式
3. ✅ **攻击与防御**：实战模拟攻击和实现安全修复
4. ✅ **Remix IDE**：熟练使用以太坊开发工具
5. ✅ **安全思维**：培养编写安全合约的习惯

## 📁 项目结构

```
contract-security/
├── contracts/
│   ├── VulnerableBank.sol        # ❌ 存在重入漏洞的银行合约
│   ├── ReentrancyAttacker.sol    # 💥 重入攻击演示合约
│   └── SecureBank.sol            # ✅ 安全修复版本（待完成）
├── docs/
│   ├── SECURITY_NOTES.md         # 📚 详细的安全学习笔记
│   └── REMIX_DEPLOYMENT_GUIDE.md # 🚀 Remix IDE 部署指南
└── README.md                     # 📖 本文件
```

## 🚀 快速开始

### 第一步：阅读学习笔记

打开并仔细阅读 [`docs/SECURITY_NOTES.md`](docs/SECURITY_NOTES.md)，了解：
- 安全设计原则
- 重入攻击的详细原理
- 历史上的 The DAO 事件
- 其他常见漏洞类型

### 第二步：理解漏洞代码

查看 [`contracts/VulnerableBank.sol`](contracts/VulnerableBank.sol)：
```solidity
// ❌ 有漏洞的提款函数
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "Insufficient balance");

    // 问题：先转账
    (bool sent, ) = msg.sender.call{value: balance}("");
    require(sent, "Failed to send Ether");

    // 太晚了：此时攻击者已经重入
    balances[msg.sender] = 0;
}
```

### 第三步：理解攻击原理

查看 [`contracts/ReentrancyAttacker.sol`](contracts/ReentrancyAttacker.sol)：
```solidity
// 💥 攻击合约的 receive 函数
receive() external payable {
    attackCount++;

    // 在余额清零前再次提款！
    if (address(vulnerableBank).balance >= 1 ether) {
        vulnerableBank.withdraw();
    }
}
```

### 第四步：⭐ **你的任务 - 实现安全修复**

打开 [`contracts/SecureBank.sol`](contracts/SecureBank.sol)，在 `withdraw()` 函数中实现安全的提款逻辑。

**关键要求**：
1. 遵循 **CEI (Checks-Effects-Interactions)** 模式
2. 在发送 ETH **之前**更新用户余额
3. 确保重入攻击无法成功

**提示**：
```solidity
function withdraw() public {
    // TODO: 你的实现

    // 1️⃣ Checks: 检查余额

    // 2️⃣ Effects: 更新状态（关键！必须在转账前）

    // 3️⃣ Interactions: 发送 ETH
}
```

参考 `docs/SECURITY_NOTES.md` 中的"修复方案"章节。

### 第五步：在 Remix 中部署和测试

按照 [`docs/REMIX_DEPLOYMENT_GUIDE.md`](docs/REMIX_DEPLOYMENT_GUIDE.md) 的详细步骤：

1. **部署漏洞版本**
   - 部署 `VulnerableBank`
   - 多个账户存款
   - 部署 `ReentrancyAttacker`
   - 执行攻击，观察资金被盗

2. **部署安全版本**
   - 完成 `SecureBank.sol` 的修复
   - 部署 `SecureBank`
   - 再次尝试攻击
   - 验证攻击失败，资金安全

## 📚 核心概念

### 重入攻击（Reentrancy Attack）

**定义**：攻击者利用合约在外部调用返回之前重复执行同一函数的漏洞。

**危害**：
- 2016 年 The DAO 事件：损失 6000 万美元
- 导致以太坊分裂为 ETH 和 ETC

**攻击流程**：
```
1. 用户调用 withdraw()
2. 合约向用户转账（触发攻击者的 receive 函数）
3. 攻击者在 receive 中再次调用 withdraw()
4. 由于余额未清零，攻击者可以重复提款
5. 重复步骤 2-4，直到合约资金耗尽
```

### CEI 模式（Checks-Effects-Interactions）

**最重要的 Solidity 安全模式之一**

1. **Checks（检查）**：验证条件、权限、余额
2. **Effects（状态更新）**：修改合约状态变量
3. **Interactions（外部交互）**：调用外部合约或发送 ETH

**关键原则**：
> 永远在外部调用（Interactions）之前完成状态更新（Effects）

## 🛡️ 安全最佳实践

### 1. 遵循 CEI 模式
```solidity
// ✅ 正确
function withdraw() public {
    uint256 amount = balances[msg.sender];
    require(amount > 0);

    balances[msg.sender] = 0;  // 先更新状态

    (bool sent, ) = msg.sender.call{value: amount}("");
    require(sent);
}
```

### 2. 使用 ReentrancyGuard（额外保护）
```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SecureBank is ReentrancyGuard {
    function withdraw() public nonReentrant {
        // 函数逻辑
    }
}
```

### 3. Pull over Push 模式
```solidity
// 让用户自己提取，而不是主动发送
mapping(address => uint256) public pendingWithdrawals;

function requestWithdrawal() public {
    balances[msg.sender] = 0;
    pendingWithdrawals[msg.sender] += balances[msg.sender];
}

function withdraw() public {
    uint256 amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0;
    // 发送 ETH
}
```

## 🎓 学习路径

### 初级
- [ ] 阅读 `SECURITY_NOTES.md`
- [ ] 理解 `VulnerableBank.sol` 的漏洞
- [ ] 理解 `ReentrancyAttacker.sol` 的攻击原理
- [ ] 在 Remix 中部署和测试漏洞版本

### 中级
- [ ] 完成 `SecureBank.sol` 的修复
- [ ] 在 Remix 中验证修复效果
- [ ] 实现 ReentrancyGuard 版本
- [ ] 对比不同修复方案的 Gas 成本

### 高级
- [ ] 编写 Hardhat/Foundry 自动化测试
- [ ] 学习其他漏洞类型（预言机操纵、整数溢出等）
- [ ] 参与 Ethernaut、Damn Vulnerable DeFi 挑战
- [ ] 阅读真实审计报告

## 📖 参考资源

### 官方文档
- [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

### 学习平台
- [Ethernaut](https://ethernaut.openzeppelin.com/) - 安全闯关游戏
- [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) - DeFi 安全挑战
- [Capture the Ether](https://capturetheether.com/) - 以太坊安全游戏

### 安全工具
- [Slither](https://github.com/crytic/slither) - 静态分析工具
- [Mythril](https://github.com/ConsenSys/mythril) - 安全分析框架
- [Echidna](https://github.com/crytic/echidna) - 模糊测试工具

### 审计机构
- [Trail of Bits](https://www.trailofbits.com/)
- [OpenZeppelin](https://www.openzeppelin.com/security-audits)
- [Consensys Diligence](https://consensys.net/diligence/)

## ⚠️ 免责声明

**本项目仅供教育目的使用。**

- ❌ 不要在主网部署这些合约
- ❌ 不要使用真实资金测试
- ❌ 不要将攻击技术用于恶意目的

所有代码示例都包含已知漏洞，仅用于学习安全编程。在实际项目中，务必：
1. 使用成熟的安全库（如 OpenZeppelin）
2. 经过专业安全审计
3. 进行全面测试
4. 遵循最佳实践

## 🤝 贡献

欢迎提交问题和改进建议！如果你发现了新的安全问题或更好的修复方案，请分享你的见解。

## 📄 许可证

MIT License - 自由使用和学习

---

## 💡 下一步行动

1. ✅ **阅读学习笔记**：`docs/SECURITY_NOTES.md`
2. ✅ **理解漏洞代码**：`contracts/VulnerableBank.sol`
3. ⭐ **完成修复任务**：`contracts/SecureBank.sol`（你的实践机会！）
4. ✅ **部署和测试**：按照 `docs/REMIX_DEPLOYMENT_GUIDE.md`
5. ✅ **验证修复效果**：确保攻击失败

**记住**：在区块链上，代码即法律，一旦部署无法修改。安全始终是第一位的！🔒

---

**祝你学习愉快！如有问题，欢迎查阅详细文档或提问。**
