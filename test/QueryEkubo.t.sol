// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import {QueryEkubo} from "../src/QueryEkubo.sol";

contract QueryEkuboTest is Test {
    QueryEkubo quote;

    address CORE = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        quote = new QueryEkubo(CORE);
    }

    function test_queryEkubo() public {
        address token0 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address token1 = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
        bytes32 config = 0x00000000000000000000000000000000000000000020c49ba5e353f80000137c;
        uint256 interation = 1000;
        bytes memory tickInfo = quote.queryEkuboTicksSuperCompactByTokens(token0, token1, config, interation);
        console2.logBytes(tickInfo);
    }
}