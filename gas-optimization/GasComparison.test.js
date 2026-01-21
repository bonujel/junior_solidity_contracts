/**
 * Gas 对比测试脚本
 *
 * 使用方法：
 * 1. 确保安装了 Hardhat: npm install --save-dev hardhat
 * 2. 运行测试: npx hardhat test GasComparison.test.js
 *
 * 注意：这是一个示例测试脚本，需要 Hardhat 环境才能运行
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Gas Optimization Comparison", function () {
    let owner, user1, user2;
    let marketplaceBefore, marketplaceAfter;

    // 测试数据
    const PRICE = ethers.utils.parseEther("1.0");  // 1 ETH
    const SMALL_PRICE = ethers.utils.parseEther("0.1");  // 0.1 ETH

    before(async function () {
        [owner, user1, user2] = await ethers.getSigners();
    });

    beforeEach(async function () {
        // 部署未优化版本
        const MarketplaceBefore = await ethers.getContractFactory("NFTMarketplace_Before");
        marketplaceBefore = await MarketplaceBefore.deploy();
        await marketplaceBefore.deployed();

        // 部署优化版本
        const MarketplaceAfter = await ethers.getContractFactory("NFTMarketplace_After");
        marketplaceAfter = await MarketplaceAfter.deploy();
        await marketplaceAfter.deployed();

        console.log("\n=== 合约部署完成 ===");
        console.log("未优化版本地址:", marketplaceBefore.address);
        console.log("优化版本地址:", marketplaceAfter.address);
    });

    describe("部署成本对比", function () {
        it("应该显示部署 gas 消耗", async function () {
            const deploymentBefore = await ethers.provider.getTransactionReceipt(
                marketplaceBefore.deployTransaction.hash
            );
            const deploymentAfter = await ethers.provider.getTransactionReceipt(
                marketplaceAfter.deployTransaction.hash
            );

            console.log("\n📊 部署成本对比:");
            console.log("未优化版本:", deploymentBefore.gasUsed.toString(), "gas");
            console.log("优化版本:", deploymentAfter.gasUsed.toString(), "gas");

            const savings = deploymentBefore.gasUsed.sub(deploymentAfter.gasUsed);
            const percentage = savings.mul(100).div(deploymentBefore.gasUsed);

            console.log("节省:", savings.toString(), "gas");
            console.log("节省比例:", percentage.toString() + "%");
        });
    });

    describe("listItem 函数对比", function () {
        it("应该对比单次上架的 gas 消耗", async function () {
            // 未优化版本
            const txBefore = await marketplaceBefore.connect(user1).listItem(1, PRICE);
            const receiptBefore = await txBefore.wait();

            // 优化版本
            const txAfter = await marketplaceAfter.connect(user1).listItem(1, PRICE);
            const receiptAfter = await txAfter.wait();

            console.log("\n📊 listItem 单次调用对比:");
            console.log("未优化版本:", receiptBefore.gasUsed.toString(), "gas");
            console.log("优化版本:", receiptAfter.gasUsed.toString(), "gas");

            const savings = receiptBefore.gasUsed.sub(receiptAfter.gasUsed);
            const percentage = savings.mul(100).div(receiptBefore.gasUsed);

            console.log("节省:", savings.toString(), "gas");
            console.log("节省比例:", percentage.toString() + "%");
        });
    });

    describe("buyItem 函数对比", function () {
        beforeEach(async function () {
            // 先上架商品
            await marketplaceBefore.connect(user1).listItem(1, PRICE);
            await marketplaceAfter.connect(user1).listItem(1, PRICE);
        });

        it("应该对比购买的 gas 消耗", async function () {
            // 未优化版本
            const txBefore = await marketplaceBefore.connect(user2).buyItem(0, {
                value: PRICE
            });
            const receiptBefore = await txBefore.wait();

            // 优化版本
            const txAfter = await marketplaceAfter.connect(user2).buyItem(0, {
                value: PRICE
            });
            const receiptAfter = await txAfter.wait();

            console.log("\n📊 buyItem 函数对比:");
            console.log("未优化版本:", receiptBefore.gasUsed.toString(), "gas");
            console.log("优化版本:", receiptAfter.gasUsed.toString(), "gas");

            const savings = receiptBefore.gasUsed.sub(receiptAfter.gasUsed);
            const percentage = savings.mul(100).div(receiptBefore.gasUsed);

            console.log("节省:", savings.toString(), "gas");
            console.log("节省比例:", percentage.toString() + "%");
        });
    });

    describe("getUserListings 函数对比", function () {
        beforeEach(async function () {
            // 创建 10 个商品
            for (let i = 0; i < 10; i++) {
                await marketplaceBefore.connect(user1).listItem(i, SMALL_PRICE);
                await marketplaceAfter.connect(user1).listItem(i, SMALL_PRICE);
            }
        });

        it("应该对比获取用户商品列表的 gas 消耗", async function () {
            // 未优化版本
            const txBefore = await marketplaceBefore.getUserListings(user1.address);
            const gasBefore = await marketplaceBefore.estimateGas.getUserListings(user1.address);

            // 优化版本
            const txAfter = await marketplaceAfter.getUserListings(user1.address);
            const gasAfter = await marketplaceAfter.estimateGas.getUserListings(user1.address);

            console.log("\n📊 getUserListings (10项) 函数对比:");
            console.log("未优化版本:", gasBefore.toString(), "gas");
            console.log("优化版本:", gasAfter.toString(), "gas");

            const savings = gasBefore.sub(gasAfter);
            const percentage = savings.mul(100).div(gasBefore);

            console.log("节省:", savings.toString(), "gas");
            console.log("节省比例:", percentage.toString() + "%");
        });
    });

    describe("batchCancelListings 函数对比", function () {
        beforeEach(async function () {
            // 创建 5 个商品
            for (let i = 0; i < 5; i++) {
                await marketplaceBefore.connect(user1).listItem(i, SMALL_PRICE);
                await marketplaceAfter.connect(user1).listItem(i, SMALL_PRICE);
            }
        });

        it("应该对比批量取消的 gas 消耗", async function () {
            const listingIds = [0, 1, 2, 3, 4];

            // 未优化版本
            const txBefore = await marketplaceBefore.connect(user1).batchCancelListings(listingIds);
            const receiptBefore = await txBefore.wait();

            // 优化版本
            const txAfter = await marketplaceAfter.connect(user1).batchCancelListings(listingIds);
            const receiptAfter = await txAfter.wait();

            console.log("\n📊 batchCancelListings (5项) 函数对比:");
            console.log("未优化版本:", receiptBefore.gasUsed.toString(), "gas");
            console.log("优化版本:", receiptAfter.gasUsed.toString(), "gas");

            const savings = receiptBefore.gasUsed.sub(receiptAfter.gasUsed);
            const percentage = savings.mul(100).div(receiptBefore.gasUsed);

            console.log("节省:", savings.toString(), "gas");
            console.log("节省比例:", percentage.toString() + "%");
        });
    });

    describe("batchListItems 函数对比 (仅优化版本)", function () {
        it("应该展示批量上架的 gas 效率", async function () {
            const tokenIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
            const prices = Array(10).fill(SMALL_PRICE);

            // 优化版本的批量操作
            const txBatch = await marketplaceAfter.connect(user1).batchListItems(tokenIds, prices);
            const receiptBatch = await txBatch.wait();

            // 未优化版本的单个操作 (模拟)
            let totalGasBefore = ethers.BigNumber.from(0);
            for (let i = 0; i < 10; i++) {
                const tx = await marketplaceBefore.connect(user1).listItem(i, SMALL_PRICE);
                const receipt = await tx.wait();
                totalGasBefore = totalGasBefore.add(receipt.gasUsed);
            }

            console.log("\n📊 批量操作效率对比 (10项):");
            console.log("未优化版本 (10次单独调用):", totalGasBefore.toString(), "gas");
            console.log("优化版本 (1次批量调用):", receiptBatch.gasUsed.toString(), "gas");

            const savings = totalGasBefore.sub(receiptBatch.gasUsed);
            const percentage = savings.mul(100).div(totalGasBefore);

            console.log("节省:", savings.toString(), "gas");
            console.log("节省比例:", percentage.toString() + "%");
        });
    });

    describe("综合性能测试", function () {
        it("应该展示完整流程的 gas 对比", async function () {
            console.log("\n📊 完整流程 Gas 对比:");
            console.log("流程: 上架商品 → 购买 → 取消另一个商品");

            // === 未优化版本 ===
            let totalBefore = ethers.BigNumber.from(0);

            // 1. 上架两个商品
            let tx = await marketplaceBefore.connect(user1).listItem(1, PRICE);
            let receipt = await tx.wait();
            totalBefore = totalBefore.add(receipt.gasUsed);

            tx = await marketplaceBefore.connect(user1).listItem(2, PRICE);
            receipt = await tx.wait();
            totalBefore = totalBefore.add(receipt.gasUsed);

            // 2. 购买第一个
            tx = await marketplaceBefore.connect(user2).buyItem(0, { value: PRICE });
            receipt = await tx.wait();
            totalBefore = totalBefore.add(receipt.gasUsed);

            // 3. 取消第二个
            tx = await marketplaceBefore.connect(user1).cancelListing(1);
            receipt = await tx.wait();
            totalBefore = totalBefore.add(receipt.gasUsed);

            // === 优化版本 ===
            let totalAfter = ethers.BigNumber.from(0);

            // 1. 上架两个商品
            tx = await marketplaceAfter.connect(user1).listItem(1, PRICE);
            receipt = await tx.wait();
            totalAfter = totalAfter.add(receipt.gasUsed);

            tx = await marketplaceAfter.connect(user1).listItem(2, PRICE);
            receipt = await tx.wait();
            totalAfter = totalAfter.add(receipt.gasUsed);

            // 2. 购买第一个
            tx = await marketplaceAfter.connect(user2).buyItem(0, { value: PRICE });
            receipt = await tx.wait();
            totalAfter = totalAfter.add(receipt.gasUsed);

            // 3. 取消第二个
            tx = await marketplaceAfter.connect(user1).cancelListing(1);
            receipt = await tx.wait();
            totalAfter = totalAfter.add(receipt.gasUsed);

            console.log("\n未优化版本总计:", totalBefore.toString(), "gas");
            console.log("优化版本总计:", totalAfter.toString(), "gas");

            const savings = totalBefore.sub(totalAfter);
            const percentage = savings.mul(100).div(totalBefore);

            console.log("总节省:", savings.toString(), "gas");
            console.log("节省比例:", percentage.toString() + "%");
        });
    });

    describe("总结报告", function () {
        it("应该生成优化总结", async function () {
            console.log("\n" + "=".repeat(60));
            console.log("Gas 优化总结报告");
            console.log("=".repeat(60));
            console.log("\n关键优化技术:");
            console.log("1. ✅ Struct 位压缩 (4 slots → 2 slots)");
            console.log("2. ✅ Storage 缓存到 Memory");
            console.log("3. ✅ 使用 constant/immutable");
            console.log("4. ✅ 循环优化 (缓存 length, ++i, unchecked)");
            console.log("5. ✅ external + calldata");
            console.log("6. ✅ 批量操作优化");
            console.log("7. ✅ 短路求值");
            console.log("8. ✅ call 代替 transfer");
            console.log("\n预期优化效果:");
            console.log("- 部署成本: 节省 15-25%");
            console.log("- 单次操作: 节省 25-35%");
            console.log("- 批量操作: 节省 40-60%");
            console.log("\n" + "=".repeat(60));
        });
    });
});
