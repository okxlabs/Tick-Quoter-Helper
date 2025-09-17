// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import "../src/Quote.sol";

interface IQuoter {
    function queryEkuboTicksSuperCompactByTokens(address token0, address token1, bytes32 config)
        external
        view
        returns (bytes memory);
}

contract EkuboTest is Test {
    QueryData quoter = QueryData(0x023F4430f5EA34F4305458c5F773FFAcD9f40a91);

    function setUp() public {
        vm.createSelectFork("wss://ethereum-rpc.publicnode.com", 23382015);
    }
    // address (20 bytes) | fee (8 bytes) | tickSpacing (4 bytes)

    function _toConfig(uint256 fee, uint256 tickSpacing, address hooks) internal pure returns (bytes32) {
        return bytes32(uint256(fee) << 32 + uint256(tickSpacing) + uint256(uint160(hooks)) << 96);
    }

    function _test_ekubo() public {
        QueryEkuboTicksSuperCompact.PoolKey memory poolKey = QueryEkuboTicksSuperCompact.PoolKey({
            token0: address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
            token1: address(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            config: 0x553a2efc570c9e104942cec6ac1c18118e54c091000010c6f7a0b5ee00000002
        });
        bytes memory tickInfo = IQuoter(0x023F4430f5EA34F4305458c5F773FFAcD9f40a91).queryEkuboTicksSuperCompactByTokens(
            poolKey.token0, poolKey.token1, poolKey.config
        );
        uint256 len;
        uint256 offset;
        assembly {
            len := mload(tickInfo)
            offset := add(tickInfo, 32)
        }
        for (uint256 i = 0; i < len / 32; i++) {
            int256 res;
            assembly {
                res := mload(offset)
                offset := add(offset, 32)
            }
            console2.log("tick: %d", int128(res >> 128));
            console2.log("l: %d", int128(res));
        }
    }

    function test_ekubo2() public {
        QueryEkuboTicksSuperCompact.PoolKey memory poolKey = QueryEkuboTicksSuperCompact.PoolKey({
            token0: address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
            token1: address(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            config: 0x553a2efc570c9e104942cec6ac1c18118e54c091000010c6f7a0b5ee00000002
        });
        quoter = new QueryData(address(0), address(0), address(0));
        bytes memory tickInfo = quoter.queryEkuboTicksSuperCompact(poolKey, 10);
        uint256 len;
        uint256 offset;
        assembly {
            len := mload(tickInfo)
            offset := add(tickInfo, 32)
        }
        for (uint256 i = 0; i < len / 32; i++) {
            int256 res;
            assembly {
                res := mload(offset)
                offset := add(offset, 32)
            }
            console2.log("tick: %d", int128(res >> 128));
            console2.log("l: %d", int128(res));
        }
    }
}
