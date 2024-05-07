// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "hardhat/console.sol";

contract Encoding {
    constructor() {}

    struct enco {
        address addr;
        uint256 val;
    }

    function test(bytes memory _routes) external {
        enco memory decoded = abi.decode(_routes, (enco));
        console.log(decoded.val, "from encode contract");
    }
}

