// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import {QueryData} from "../src/Quote.sol";

contract UniV4QuoterTest is Test {
    QueryData quoter = QueryData(0x8F8Bd31d1B9e8E15c0E36dC5b2645cfE4b5713BA);
    // address stateView = 0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227;
    // address positionManager = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    // base
    address stateView = 0xA3c0c9b65baD0b08107Aa264b0f3dB444b867A71;
    address positionManager = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    // unichain
    // QueryData quoter = QueryData(0xf3964a4Ba7371E4C44aADFAc679cE9ba8B6AdC66);

    function setUp() public {
        // vm.createSelectFork("https://mainnet.unichain.org");
        vm.createSelectFork("https://eth.llamarpc.com");
        // vm.createSelectFork("https://base.rpc.subquery.network/public");
        // quoter = new QueryData(stateView, positionManager);
    }

    function _test_univ4Quoter() public {
        // QueryData.PoolKey memory key = QueryData.PoolKey({
        //     currency0: QueryData.Currency.wrap(address(0)), // ETH
        //     currency1: QueryData.Currency.wrap(0xdAC17F958D2ee523a2206206994597C13D831ec7), // USDT
        //     fee: 500,
        //     tickSpacing: 10,
        //     hooks: IHooks(address(0))
        // });

        // bytes32 poolId = 0x72331FCB696B0151904C03584B66DC8365BC63F8A144D89A773384E3A579CA73;
        bytes32 poolId = 0x72331fcb696b0151904c03584b66dc8365bc63f8a144d89a773384e3a579ca73;
        // unichain
        // bytes32 poolId = 0x25939956ef14a098d95051d86c75890cfd623a9eeba055e46d8dd9135980b37c;
        bytes memory tickInfo = quoter.queryUniv4TicksSuperCompact(poolId, 250);
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
