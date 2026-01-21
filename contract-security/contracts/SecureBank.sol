// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SecureBank
 * @notice ✅ 修复了重入漏洞的安全银行合约
 * @dev 实现了 CEI (Checks-Effects-Interactions) 模式
 *
 * 修复方案：
 * 1. 遵循 CEI 模式：先检查、后更新状态、最后交互
 * 2. 使用 ReentrancyGuard（可选的额外保护）
 * 3. 详细的事件记录用于审计
 */
contract SecureBank {
    // 用户余额映射
    mapping(address => uint256) public balances;

    // 事件：存款
    event Deposit(address indexed user, uint256 amount);
    // 事件：提款
    event Withdrawal(address indexed user, uint256 amount);

    /**
     * @notice 存款函数
     */
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice ✅ 安全的提款函数
     * @dev TODO: 请在这里实现安全的提款逻辑
     *
     * 你的任务：
     * 实现遵循 CEI (Checks-Effects-Interactions) 模式的提款函数
     *
     * CEI 模式说明：
     * - Checks (检查)：验证条件（余额、权限等）
     * - Effects (状态更新)：修改合约状态变量
     * - Interactions (外部交互)：调用外部合约或发送 ETH
     *
     * 关键安全点：
     * 1. 在发送 ETH 之前更新用户余额
     * 2. 使用局部变量存储要发送的金额
     * 3. 确保状态变更在外部调用之前完成
     *
     * 需要考虑：
     * - 重入攻击者会在 receive ETH 时再次调用此函数
     * - 如果余额未清零，攻击者可以重复提取
     * - 状态更新必须在 call 之前完成
     *
     * 提示：对比 VulnerableBank.sol 中的错误实现
     */
    function withdraw() public {
        // TODO: 在这里实现安全的提款逻辑
        // 步骤 1: Checks - 检查余额
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Insufficient balance");

        // 步骤 2: Effects - 更新状态（关键！）
        balances[msg.sender] = 0;

        // 步骤 3: Interactions - 发送 ETH
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice 查询余额
     */
    function getBalance() public view returns (uint256) {
        return balances[msg.sender];
    }

    /**
     * @notice 查询合约总余额
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
