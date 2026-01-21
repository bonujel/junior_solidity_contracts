# Solidity 智能合约安全学习笔记

## 📚 目录
1. [安全设计原则](#安全设计原则)
2. [重入攻击深度解析](#重入攻击深度解析)
3. [其他常见漏洞](#其他常见漏洞)
4. [实战案例分析](#实战案例分析)
5. [修复方案对比](#修复方案对比)

---

## 🛡️ 安全设计原则

### 1. 最小权限原则 (Principle of Least Privilege)

**核心思想**：每个函数、合约和用户应仅拥有完成其任务所需的最小权限。

**实践要点**：
```solidity
// ✅ 良好的权限控制
contract GoodExample {
    address public owner;
    mapping(address => bool) public admins;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Not admin");
        _;
    }

    // 只有 owner 可以添加管理员
    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
    }

    // 管理员可以执行日常操作
    function dailyOperation() external onlyAdmin {
        // ...
    }
}
```

**推荐工具**：
- OpenZeppelin 的 `Ownable` 合约
- OpenZeppelin 的 `AccessControl` 合约（角色管理）

---

### 2. 模块化结构便于审计

**核心思想**：将复杂逻辑拆分为小而专注的函数，便于审计和测试。

**实践要点**：
```solidity
// ❌ 不良实践：巨大的函数，难以审计
function complexOperation() external {
    // 100+ 行代码，包含多个逻辑分支
}

// ✅ 良好实践：模块化
function complexOperation() external {
    _validateInputs();
    _updateState();
    _performCalculations();
    _emitEvents();
}

function _validateInputs() private {
    // 验证逻辑
}

function _updateState() private {
    // 状态更新逻辑
}
```

**好处**：
- 每个函数职责单一，易于理解
- 便于单元测试
- 降低审计成本
- 减少错误概率

---

### 3. 显式错误处理与事件记录

**核心思想**：使用 `require`、`revert` 明确错误条件，用事件记录关键操作。

**实践要点**：
```solidity
contract GoodPractice {
    event Withdrawal(address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawalFailed(address indexed user, uint256 amount, string reason);

    function withdraw(uint256 amount) external {
        // ✅ 明确的错误检查
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        // ✅ 详细的事件记录
        (bool success, ) = msg.sender.call{value: amount}("");

        if (success) {
            emit Withdrawal(msg.sender, amount, block.timestamp);
        } else {
            // 回滚状态
            balances[msg.sender] += amount;
            emit WithdrawalFailed(msg.sender, amount, "Transfer failed");
            revert("Withdrawal failed");
        }
    }
}
```

**为什么重要**：
- 链下监控和分析
- 快速定位问题
- 审计追踪
- 用户反馈

---

## 🔥 重入攻击深度解析

### 什么是重入攻击？

重入攻击（Reentrancy Attack）是智能合约中最危险的漏洞之一，允许攻击者在外部调用返回之前重复执行同一函数。

### 历史事件：The DAO 事件

**时间**：2016年6月
**损失**：约 6000 万美元（当时约 360 万 ETH）
**后果**：以太坊社区分裂，形成 ETH 和 ETC

**攻击流程**：
```
1. The DAO 合约允许用户提取资金
2. 合约在转账前未清零余额
3. 攻击者部署恶意合约，在 fallback 中再次调用提款函数
4. 由于余额未清零，攻击者反复提款
5. 最终耗尽合约所有资金
```

### 技术原理

#### 有漏洞的代码
```solidity
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0);

    // ❌ 危险：先转账
    (bool sent, ) = msg.sender.call{value: balance}("");
    require(sent);

    // ❌ 太晚了：此时攻击者已经重入
    balances[msg.sender] = 0;
}
```

#### 攻击流程图
```
[正常用户] ──┐
             │
             ▼
    ┌──────────────────┐
    │  VulnerableBank  │
    │                  │
    │  withdraw()      │◄─────┐
    │  1. 检查余额      │      │
    │  2. 发送 ETH ──┐  │      │
    │  3. 清零余额   │  │      │ 重入！
    └────────────────┼──┘      │
                     │         │
                     ▼         │
    ┌──────────────────┐      │
    │  Attacker        │      │
    │                  │      │
    │  receive() {     │      │
    │    withdraw() ───┼──────┘
    │  }               │
    └──────────────────┘
```

### 攻击示例分析

查看 `contracts/ReentrancyAttacker.sol` 中的完整攻击代码。

**关键点**：
1. 攻击者首先存入 1 ETH
2. 调用 `attack()` 触发提款
3. 在 `receive()` 中捕获转账
4. 在余额清零前再次调用 `withdraw()`
5. 重复步骤 3-4，直到银行资金耗尽

### 修复方案：CEI 模式

**CEI = Checks-Effects-Interactions**

```solidity
function withdraw() public {
    // 1️⃣ Checks（检查）
    uint256 amount = balances[msg.sender];
    require(amount > 0, "Insufficient balance");

    // 2️⃣ Effects（状态更新）- 关键！
    balances[msg.sender] = 0;

    // 3️⃣ Interactions（外部交互）
    (bool sent, ) = msg.sender.call{value: amount}("");
    require(sent, "Failed to send Ether");

    emit Withdrawal(msg.sender, amount);
}
```

**为什么有效**：
- 即使攻击者重入，`balances[msg.sender]` 已经是 0
- 第二次调用会在 `require(amount > 0)` 处失败
- 攻击者无法重复提款

---

## ⚠️ 其他常见漏洞

### 1. 预言机操纵 (Oracle Manipulation)

**问题**：依赖不可信的外部价格源

**案例**：2020 年 Harvest Finance 闪电贷攻击，损失 3400 万美元

**漏洞代码**：
```solidity
// ❌ 危险：使用单一 DEX 价格
function getPrice() public view returns (uint256) {
    (uint256 reserve0, uint256 reserve1, ) = uniswapPair.getReserves();
    return reserve1 / reserve0;  // 可被闪电贷操纵
}
```

**修复方案**：
```solidity
// ✅ 使用 Chainlink 预言机
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SecurePrice {
    AggregatorV3Interface internal priceFeed;

    constructor() {
        // ETH/USD 价格源
        priceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    function getLatestPrice() public view returns (int) {
        (
            ,
            int price,
            ,
            uint256 updatedAt,

        ) = priceFeed.latestRoundData();

        require(updatedAt >= block.timestamp - 3600, "Stale price");
        return price;
    }
}
```

**最佳实践**：
- 使用 Chainlink 等去中心化预言机
- 实现 TWAP（时间加权平均价格）
- 多源价格验证
- 设置价格变化阈值

---

### 2. 整数溢出/下溢

**问题**：Solidity 0.8.0 之前，整数运算可能溢出

**漏洞示例**：
```solidity
// Solidity < 0.8.0
function overflow() public {
    uint8 max = 255;
    max = max + 1;  // 结果是 0（溢出）
}

function underflow() public {
    uint8 min = 0;
    min = min - 1;  // 结果是 255（下溢）
}
```

**修复方案**：

**方案 1：使用 Solidity 0.8.0+（推荐）**
```solidity
// Solidity >= 0.8.0 自动检查溢出
pragma solidity ^0.8.0;

function safe() public {
    uint8 max = 255;
    max = max + 1;  // 自动 revert
}
```

**方案 2：使用 SafeMath（旧版本）**
```solidity
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OldVersion {
    using SafeMath for uint256;

    function safeAdd(uint256 a, uint256 b) public pure returns (uint256) {
        return a.add(b);  // 溢出时自动 revert
    }
}
```

**方案 3：使用 `unchecked` 时要谨慎**
```solidity
// Solidity 0.8.0+
function gasOptimized() public {
    uint256 i;
    unchecked {
        // ⚠️ 确保逻辑上不会溢出
        for (i = 0; i < 1000; ++i) {
            // 循环变量不会溢出
        }
    }
}
```

---

### 3. 权限控制缺失

**问题**：敏感函数缺少访问控制

**漏洞代码**：
```solidity
// ❌ 任何人都可以销毁合约
contract Vulnerable {
    function destroy() public {
        selfdestruct(payable(msg.sender));
    }
}
```

**修复方案**：
```solidity
// ✅ 使用 OpenZeppelin Ownable
import "@openzeppelin/contracts/access/Ownable.sol";

contract Secure is Ownable {
    function destroy() public onlyOwner {
        selfdestruct(payable(owner()));
    }

    // 或使用自定义修饰符
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    function criticalOperation() public onlyAdmin {
        // 只有管理员可以执行
    }
}
```

**更复杂的权限管理**：
```solidity
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MultiRole is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        // 只有 MINTER_ROLE 可以铸造
    }

    function pause() public onlyRole(ADMIN_ROLE) {
        // 只有 ADMIN_ROLE 可以暂停
    }
}
```

---

### 4. 未初始化的代理合约

**问题**：代理模式下，实现合约未正确初始化，可能被攻击者接管

**案例**：Harvest Finance V3 Vault 未初始化漏洞

**漏洞代码**：
```solidity
// ❌ 危险：没有初始化保护
contract Implementation {
    address public owner;

    function setup(address _owner) public {
        owner = _owner;  // 任何人都可以调用
    }
}
```

**修复方案**：
```solidity
// ✅ 使用 OpenZeppelin Initializable
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SafeImplementation is Initializable {
    address public owner;

    function initialize(address _owner) public initializer {
        owner = _owner;  // 只能调用一次
    }
}
```

**关键点**：
- 使用 `initializer` 修饰符确保只执行一次
- 部署后立即初始化
- 考虑使用时间锁保护初始化函数

---

### 5. 前置交易/三明治攻击 (Front-Running / Sandwich Attack)

**问题**：攻击者监控内存池，在用户交易前后插入自己的交易

**攻击流程**：
```
1. 用户提交交易：购买 10 ETH 的 Token A（滑点 5%）
2. 攻击者检测到此交易
3. 攻击者发送高 gas 的交易：先购买 Token A（推高价格）
4. 用户交易执行（以更高价格买入）
5. 攻击者以更高价格卖出 Token A（获利）
```

**真实案例**：2025年3月 Uniswap V3 三明治攻击
- 用户损失：21.5 万 USDC
- 损失比例：98%
- 攻击手段：MEV bot 抢跑交易

**防护方案**：

**方案 1：设置合理的滑点保护**
```solidity
function swap(
    uint256 amountIn,
    uint256 minAmountOut  // ✅ 最小输出保护
) external {
    uint256 amountOut = _calculateSwap(amountIn);
    require(amountOut >= minAmountOut, "Slippage too high");
    // 执行交易
}
```

**方案 2：使用 Flashbots 等私有交易池**
- 交易不经过公开内存池
- 减少被 MEV bot 发现的风险

**方案 3：时间锁和承诺-揭示模式**
```solidity
// 第一步：提交承诺（hash）
function commitSwap(bytes32 commitment) external {
    commits[msg.sender] = commitment;
    commitTime[msg.sender] = block.timestamp;
}

// 第二步：揭示并执行（一段时间后）
function revealSwap(
    uint256 amountIn,
    uint256 nonce
) external {
    require(block.timestamp >= commitTime[msg.sender] + 10 minutes);
    bytes32 commitment = keccak256(abi.encodePacked(amountIn, nonce));
    require(commits[msg.sender] == commitment);
    // 执行交易
}
```

---

## 🎯 实战案例分析

### 案例 1：VulnerableBank 重入攻击

**文件位置**：`contracts/VulnerableBank.sol` 和 `contracts/ReentrancyAttacker.sol`

**场景模拟**：
1. VulnerableBank 有 10 ETH（来自10个用户，各存1 ETH）
2. 攻击者存入 1 ETH
3. 攻击者调用 `attack()`
4. 攻击者通过重入，提取所有 11 ETH
5. 其他 10 个用户血本无归

**关键代码分析**：

VulnerableBank.sol:27-36
```solidity
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "Insufficient balance");

    // ❌ 问题 1：先转账
    (bool sent, ) = msg.sender.call{value: balance}("");
    require(sent, "Failed to send Ether");

    // ❌ 问题 2：后更新状态
    balances[msg.sender] = 0;
}
```

ReentrancyAttacker.sol:48-58
```solidity
receive() external payable {
    attackCount++;
    emit ReentrancyExecuted(attackCount, address(vulnerableBank).balance);

    // 🔥 关键：余额未清零前再次提款
    if (address(vulnerableBank).balance >= 1 ether) {
        vulnerableBank.withdraw();
    }
}
```

**资金流动**：
```
初始状态：
  VulnerableBank: 10 ETH (10个用户)
  Attacker: 0 ETH

攻击步骤：
  1. Attacker 存入 1 ETH
     VulnerableBank: 11 ETH
     Attacker balance: 1 ETH

  2. Attacker 调用 attack()
     → VulnerableBank.withdraw()
     → 发送 1 ETH 给 Attacker
     → 触发 Attacker.receive()
     → 再次调用 withdraw()（余额未清零！）
     → 再发送 1 ETH...
     → 循环 11 次

  3. 最终状态：
     VulnerableBank: 0 ETH
     Attacker: 11 ETH（盗取了10个用户的资金）
```

---

## 🔧 修复方案对比

### 方案 1：CEI 模式（推荐）

**优点**：
- 简单直接
- Gas 成本低
- 不依赖外部库

**实现**：
```solidity
function withdraw() public {
    uint256 amount = balances[msg.sender];
    require(amount > 0);

    // ✅ 先更新状态
    balances[msg.sender] = 0;

    // ✅ 再转账
    (bool sent, ) = msg.sender.call{value: amount}("");
    require(sent);
}
```

---

### 方案 2：ReentrancyGuard（额外保护）

**优点**：
- 多层防护
- 适用于复杂合约
- OpenZeppelin 标准库

**实现**：
```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SecureBank is ReentrancyGuard {
    function withdraw() public nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0);

        balances[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent);
    }
}
```

**工作原理**：
```solidity
// OpenZeppelin ReentrancyGuard 简化版
contract ReentrancyGuard {
    uint256 private _status;

    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");
        _status = 2;
        _;
        _status = 1;
    }
}
```

---

### 方案 3：Pull over Push（拉取而非推送）

**概念**：不主动发送 ETH，让用户自己提取

**实现**：
```solidity
contract PullPayment {
    mapping(address => uint256) public pendingWithdrawals;

    function requestWithdrawal() public {
        uint256 amount = balances[msg.sender];
        require(amount > 0);

        balances[msg.sender] = 0;
        pendingWithdrawals[msg.sender] += amount;  // 标记待提取
    }

    function withdraw() public {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0);

        pendingWithdrawals[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent);
    }
}
```

**优点**：
- 最安全
- 用户自主控制
- 适合复杂支付场景

**缺点**：
- 需要两步操作
- 用户体验稍差

---

### 方案对比表

| 方案 | 安全性 | Gas 成本 | 复杂度 | 适用场景 |
|------|--------|----------|--------|----------|
| CEI 模式 | ⭐⭐⭐⭐ | 低 | 低 | 简单提款逻辑 |
| ReentrancyGuard | ⭐⭐⭐⭐⭐ | 中 | 中 | 复杂合约多函数 |
| Pull Payment | ⭐⭐⭐⭐⭐ | 高 | 高 | 批量支付、分红 |

---

## 📝 学习检查清单

完成以下任务以验证学习成果：

- [ ] 阅读 `VulnerableBank.sol`，理解漏洞原理
- [ ] 阅读 `ReentrancyAttacker.sol`，理解攻击流程
- [ ] **实践任务**：在 `SecureBank.sol` 中实现安全的 `withdraw()` 函数
- [ ] 在 Remix IDE 中部署三个合约
- [ ] 模拟攻击：部署 VulnerableBank → 部署 ReentrancyAttacker → 执行攻击
- [ ] 验证修复：部署 SecureBank → 尝试攻击 → 确认攻击失败
- [ ] 对比 gas 成本：CEI vs ReentrancyGuard
- [ ] 额外挑战：实现一个使用 Pull Payment 模式的分红合约

---

## 🔗 参考资源

### 官方文档
- [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

### 学习资源
- [Ethernaut](https://ethernaut.openzeppelin.com/) - 以太坊安全闯关游戏
- [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) - DeFi 安全挑战
- [Consensys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)

### 审计报告
- [Trail of Bits 公开审计](https://github.com/trailofbits/publications)
- [OpenZeppelin 审计报告](https://blog.openzeppelin.com/security-audits)

### 漏洞数据库
- [SWC Registry](https://swcregistry.io/) - 智能合约弱点分类
- [Rekt News](https://rekt.news/) - DeFi 黑客事件追踪

---

## 💡 最后的建议

1. **永远不要相信外部输入**：验证所有参数
2. **遵循 CEI 模式**：这是最基础的安全实践
3. **使用成熟的库**：不要重新发明轮子（OpenZeppelin）
4. **全面测试**：单元测试 + 集成测试 + 模糊测试
5. **专业审计**：重要合约务必经过专业审计
6. **持续学习**：安全是一个不断演进的领域

---

**记住**：在区块链上，代码即法律，一旦部署无法修改。安全始终是第一位的！🔒
