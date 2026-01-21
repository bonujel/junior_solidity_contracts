// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NFT市场合约 - 优化版本
 * @notice 应用了多种 Gas 优化技巧
 */
contract NFTMarketplace_After {

    // 优化1: 位压缩 - 将多个变量打包到同一个 storage slot
    struct Listing {
        address seller;      // 20 bytes - slot 0
        uint96 price;        // 12 bytes - slot 0 (uint96 足够存储价格)
        bool isActive;       // 1 byte  - slot 1
        uint32 timestamp;    // 4 bytes - slot 1 (uint32 可以存储到 2106 年)
        // 总共使用 2 个 slot 而不是 4 个！
    }

    // 优化2: 使用 private/internal 而不是 public (减少自动 getter)
    mapping(uint256 => Listing) private listings;
    mapping(address => uint256[]) private userListings;

    uint256 private listingCount;
    uint256 private totalVolume;
    address private immutable owner; // 使用 immutable 节省 gas
    uint256 private constant FEE_PERCENTAGE = 250; // 使用 constant
    uint256 private dynamicFeePercentage; // 可动态调整的费率（如果需要）

    event ItemListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ItemSold(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor() {
        owner = msg.sender;
        dynamicFeePercentage = FEE_PERCENTAGE; // 初始化为默认值
    }

    // 优化3: 使用 external 而不是 public
    // 优化4: 缓存 storage 变量到 memory
    function listItem(uint256 tokenId, uint96 price) external {
        require(price > 0, "Price must be greater than 0");

        // 缓存 listingCount 到局部变量，避免多次 SLOAD
        uint256 currentListingId = listingCount;

        listings[currentListingId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true,
            timestamp: uint32(block.timestamp)
        });

        userListings[msg.sender].push(currentListingId);

        // 使用 unchecked 块优化算术运算 (Solidity 0.8+ 默认检查溢出)
        unchecked {
            listingCount = currentListingId + 1;
        }

        emit ItemListed(tokenId, msg.sender, price);
    }

    // 优化5: 缓存 array.length
    // 优化6: 使用 ++i 而不是 i++
    function getUserListings(address user) external view returns (uint256[] memory) {
        uint256[] storage userListing = userListings[user];
        uint256 length = userListing.length; // 缓存长度

        uint256[] memory result = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            result[i] = userListing[i];
            unchecked { ++i; } // ++i 比 i++ 节省 gas
        }

        return result;
    }

    // 优化7: 一次性读取 storage 到 memory
    function buyItem(uint256 listingId) external payable {
        // 一次性读取整个 struct 到 memory
        Listing memory listing = listings[listingId];

        require(listing.isActive, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");

        // 使用 memory 变量进行计算
        uint256 price = listing.price;
        address seller = listing.seller;

        // 优化8: 使用位运算代替除法 (如果可能)
        // fee = (price * 250) / 10000 = price * 0.025
        uint256 fee = (price * FEE_PERCENTAGE) / 10000;
        uint256 sellerAmount;
        unchecked {
            sellerAmount = price - fee;
        }

        // 优化9: 批量更新 storage (先计算，最后一次性写入)
        listings[listingId].isActive = false;

        unchecked {
            totalVolume += price;
        }

        // 优化10: 使用 call 而不是 transfer (更灵活且节省 gas)
        (bool successSeller,) = payable(seller).call{value: sellerAmount}("");
        require(successSeller, "Transfer to seller failed");

        (bool successOwner,) = payable(owner).call{value: fee}("");
        require(successOwner, "Transfer to owner failed");

        emit ItemSold(listingId, msg.sender, price);
    }

    // 优化11: 短路条件判断，先检查更便宜的条件
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];

        // 先检查 msg.sender (更便宜)，再检查 isActive
        require(listing.seller == msg.sender, "Not the seller");
        require(listing.isActive, "Already inactive");

        listing.isActive = false;
    }

    // 优化12: 移除不必要的字符串比较，使用 modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function updateFee(uint256 newFee) external onlyOwner {
        // 移除了字符串密码验证，使用更安全的 onlyOwner modifier
        require(newFee <= 1000, "Fee too high"); // 10% 上限
        dynamicFeePercentage = newFee;
    }

    // 优化13: 批量操作优化
    function batchCancelListings(uint256[] calldata listingIds) external {
        uint256 length = listingIds.length;

        for (uint256 i = 0; i < length;) {
            uint256 listingId = listingIds[i];
            Listing storage listing = listings[listingId];

            // 使用局部变量减少 storage 访问
            if (listing.seller == msg.sender && listing.isActive) {
                listing.isActive = false;
            }

            unchecked { ++i; }
        }
    }

    // 额外优化: 使用 calldata 而不是 memory (对于外部函数的数组参数)
    function batchListItems(uint256[] calldata tokenIds, uint96[] calldata prices) external {
        require(tokenIds.length == prices.length, "Length mismatch");

        uint256 length = tokenIds.length;
        uint256 currentCount = listingCount;

        for (uint256 i = 0; i < length;) {
            uint256 tokenId = tokenIds[i];
            uint96 price = prices[i];

            require(price > 0, "Price must be greater than 0");

            listings[currentCount] = Listing({
                seller: msg.sender,
                price: price,
                isActive: true,
                timestamp: uint32(block.timestamp)
            });

            userListings[msg.sender].push(currentCount);

            emit ItemListed(tokenId, msg.sender, price);

            unchecked {
                ++currentCount;
                ++i;
            }
        }

        listingCount = currentCount;
    }

    // View 函数优化: 提供 getter 函数
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getListingCount() external view returns (uint256) {
        return listingCount;
    }

    function getTotalVolume() external view returns (uint256) {
        return totalVolume;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function getFeePercentage() external pure returns (uint256) {
        return FEE_PERCENTAGE; // 返回 constant 默认费率
    }

    function getDynamicFeePercentage() external view returns (uint256) {
        return dynamicFeePercentage; // 返回可调整的动态费率
    }
}
