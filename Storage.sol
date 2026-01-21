// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleStorage {
    // 这个变量用来存一个数字
    uint256 public myNumber;

    // 写入函数：把数字存进去 (要花 Gas)
    function store(uint256 _num) public {
        myNumber = _num;
    }

    // 读取函数：把数字读出来 (免费)
    function retrieve() public view returns (uint256) {
        return myNumber;
    }

    // 增加函数：把存储的数字 +1 (要花 Gas)
    function increment() public {
        myNumber = myNumber + 1;
    }
}
