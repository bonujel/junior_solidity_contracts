// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NFT市场合约 - 未优化版本
 * @notice 这个合约展示了多种常见的 Gas 浪费问题
 */
contract NFTMarketplace_Before {

    // 问题1: 使用多个独立的存储变量，没有进行位压缩
    struct Listing {
        address seller;      // 20 bytes
        uint256 price;       // 32 bytes
        bool isActive;       // 1 byte (但占用完整的 slot)
        uint256 timestamp;   // 32 bytes
    }

    // 问题2: 使用 public mapping，每次访问都读取 storage
    mapping(uint256 => Listing) public listings;
    mapping(address => uint256[]) public userListings;

    uint256 public listingCount;
    uint256 public totalVolume;
    address public owner;
    uint256 public feePercentage;

    event ItemListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ItemSold(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor() {
        owner = msg.sender;
        feePercentage = 250; // 2.5%
    }

    // 问题3: 使用 public 而不是 external
    // 问题4: 多次读写 storage
    function listItem(uint256 tokenId, uint256 price) public {
        require(price > 0, "Price must be greater than 0");

        // 多次读取 listingCount
        listings[listingCount] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true,
            timestamp: block.timestamp
        });

        // 多次写入 storage
        userListings[msg.sender].push(listingCount);
        listingCount = listingCount + 1; // 使用 + 而不是 ++

        emit ItemListed(tokenId, msg.sender, price);
    }

    // 问题5: 循环中多次读取 array.length
    // 问题6: 循环中多次读取 storage
    function getUserListings(address user) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](userListings[user].length);

        // 每次迭代都读取 userListings[user].length
        for (uint256 i = 0; i < userListings[user].length; i++) {
            result[i] = userListings[user][i];
        }

        return result;
    }

    // 问题7: 重复的存储读取
    function buyItem(uint256 listingId) public payable {
        // 第一次读取
        require(listings[listingId].isActive, "Listing not active");
        // 第二次读取
        require(msg.value >= listings[listingId].price, "Insufficient payment");

        // 第三次读取
        uint256 price = listings[listingId].price;
        // 第四次读取
        address seller = listings[listingId].seller;

        // 计算费用 (可以优化)
        uint256 fee = (price * feePercentage) / 10000;
        uint256 sellerAmount = price - fee;

        // 多次写入 storage
        listings[listingId].isActive = false;
        totalVolume = totalVolume + price;

        // 问题11: 使用 transfer (已废弃，且有 gas 限制问题)
        // transfer 限制 2300 gas，可能导致接收方合约无法执行
        payable(seller).transfer(sellerAmount);
        payable(owner).transfer(fee);

        emit ItemSold(listingId, msg.sender, price);
    }

    // 问题8: 不必要的 storage 读取
    function cancelListing(uint256 listingId) public {
        require(listings[listingId].seller == msg.sender, "Not the seller");
        require(listings[listingId].isActive, "Already inactive");

        listings[listingId].isActive = false;
    }

    // 问题9: 字符串比较效率低
    function updateFee(uint256 newFee, string memory password) public {
        require(msg.sender == owner, "Not owner");
        // 字符串比较
        require(
            keccak256(abi.encodePacked(password)) == keccak256(abi.encodePacked("admin123")),
            "Wrong password"
        );
        feePercentage = newFee;
    }

    // 问题10: 循环中的复杂计算
    function batchCancelListings(uint256[] memory listingIds) public {
        for (uint256 i = 0; i < listingIds.length; i++) {
            // 每次循环都读取 storage
            if (listings[listingIds[i]].seller == msg.sender &&
                listings[listingIds[i]].isActive) {
                listings[listingIds[i]].isActive = false;
            }
        }
    }
}
