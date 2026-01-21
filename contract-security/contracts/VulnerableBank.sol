// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title VulnerableBank
 * @notice ⚠️ 此合约包含重入漏洞，仅用于教育目的
 * @dev 演示经典的 The DAO 风格重入攻击
 *
 * 漏洞分析：
 * 1. withdraw() 函数在转账前未更新余额
 * 2. 使用 call 进行转账，会触发接收方的 fallback/receive 函数
 * 3. 攻击者可在 fallback 中重新调用 withdraw()
 * 4. 由于余额未清零，可重复提取资金
 */
contract VulnerableBank {
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
     * @notice ❌ 有漏洞的提款函数
     * @dev 问题：先转账，后更新状态
     *
     * 执行顺序：
     * 1. 检查余额
     * 2. 发送 ETH（触发攻击者的 fallback）
     * 3. 更新余额（攻击者可在步骤2中重新进入此函数）
     */
    function withdraw() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // ❌ 危险：先转账再更新状态
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");

        // ❌ 太晚了！攻击者已经在上面的 call 中重入
        balances[msg.sender] = 0;
        emit Withdrawal(msg.sender, balance);
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
