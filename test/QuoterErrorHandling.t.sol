// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {QueryData} from "../src/Quote.sol";
import "../src/extLib/QueryUniv3TicksSuperCompact.sol";
import "../src/extLib/QueryAlgebraTicksSuperCompact.sol";
import "../src/extLib/QueryUniv4TicksSuperCompact.sol";
import "../src/extLib/QueryIzumiSuperCompact.sol";
import "../src/extLib/QueryHorizonTicksSuperCompact.sol";
import "../src/extLib/QueryZoraTicksSuperCompact.sol";
import "../src/extLib/QueryPancakeInfinityLBReserveSuperCompact.sol";
import "../src/extLib/QueryFluidDexV2D3D4.sol";
import "../src/interface/IPositionManager.sol";
import "../src/interface/ICLPoolManager.sol";

/// @title Quoter Error Handling Tests
/// @notice Tests that all err_quoter_ error messages fire correctly and data is valid
contract QuoterErrorHandlingTest is Test {
    // Well-known contracts that have code but are NOT pools — used to trigger err_quoter_ reverts
    address constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_BSC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant USDC_AVAX = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address constant USDC_LINEA = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;

    // ==================== Helper ====================

    function decodeTick(bytes memory data, uint256 index) internal pure returns (int128 tick, int128 liquidityNet) {
        require(data.length >= (index + 1) * 32, "index out of bounds");
        int256 packed;
        uint256 offset = index * 32;
        assembly {
            packed := mload(add(add(data, 0x20), offset))
        }
        tick = int128(packed >> 128);
        liquidityNet = int128(packed);
    }

    function validateTickData(bytes memory data) internal pure {
        uint256 tickCount = data.length / 32;
        for (uint256 i = 0; i < tickCount; i++) {
            (int128 tick,) = decodeTick(data, i);
            require(tick >= -887272 && tick <= 887272, "tick out of valid range");
        }
    }

    // ==================== UniV3 — Error Handling ====================

    function test_univ3_notAPool_reverts_with_prefix() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        vm.expectRevert("err_quoter_univ3_tickSpacing_failed");
        QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(USDC_ETH, 100);
    }

    function test_univ3_happyPath() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        // USDC/WETH 0.3% pool
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        bytes memory data = QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, 100);
        uint256 tickCount = data.length / 32;
        console2.log("[UniV3] USDC/WETH ticks found:", tickCount);
        assertTrue(tickCount > 0, "should find ticks for active pool");
        validateTickData(data);
    }

    function test_univ3_zeroLen() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        bytes memory data = QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, 0);
        assertEq(data.length, 0, "zero len should return empty");
    }

    function test_univ3_dataConsistency() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        bytes memory data1 = QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, 50);
        bytes memory data2 = QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, 50);
        assertEq(keccak256(data1), keccak256(data2), "same query should return same data");
    }

    function test_univ3_lenBounds() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        bytes memory data50 = QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, 50);
        bytes memory data100 = QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, 100);
        assertTrue(data100.length >= data50.length, "larger len should return >= ticks");
    }

    // ==================== Algebra — Error Handling ====================

    function test_algebra_notAPool_reverts_with_prefix() public {
        vm.createSelectFork(vm.envOr("AVAX_RPC_URL", string("https://avalanche.drpc.org")));
        vm.expectRevert("err_quoter_algebra_globalState_failed");
        QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact(USDC_AVAX, 100);
    }

    function test_algebra_integral_notAPool_reverts_with_prefix() public {
        vm.createSelectFork(vm.envOr("AVAX_RPC_URL", string("https://avalanche.drpc.org")));
        vm.expectRevert("err_quoter_algebra_integral_ticks_failed");
        QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact2_v2(USDC_AVAX, 20);
    }

    function test_algebra_integral_happyPath() public {
        vm.createSelectFork(vm.envOr("AVAX_RPC_URL", string("https://avalanche.drpc.org")));
        address pool = 0x1B4d11Ab4658744714D1A6D6633247eFBd816be5;
        bytes memory data = QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact2_v2(pool, 20);
        uint256 tickCount = data.length / 32;
        console2.log("[Algebra Integral] ticks found:", tickCount);
        assertTrue(tickCount > 0, "should find ticks");
        validateTickData(data);
    }

    // ==================== UniV4 — Error Handling ====================

    function test_univ4_zeroTickSpacing_reverts() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        address stateView = 0xd13Dd3D6E93f276FAfc9Db9E6BB47C1180aeE0c4;
        IPositionManager.PoolKey memory badKey = IPositionManager.PoolKey({
            currency0: IPositionManager.Currency.wrap(address(0)),
            currency1: IPositionManager.Currency.wrap(address(0x1)),
            fee: 500,
            tickSpacing: 0,
            hooks: IHooks(address(0))
        });
        vm.expectRevert("err_quoter_univ4_tickSpacing_zero");
        QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactForNoPositionManager(
            bytes32(uint256(1)), 100, stateView, badKey
        );
    }

    function test_univ4_notAPool_stateView_reverts() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        IPositionManager.PoolKey memory key = IPositionManager.PoolKey({
            currency0: IPositionManager.Currency.wrap(address(0)),
            currency1: IPositionManager.Currency.wrap(address(0x1)),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        vm.expectRevert("err_quoter_univ4_getSlot0_failed");
        QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactForNoPositionManager(
            bytes32(uint256(1)), 100, USDC_BSC, key
        );
    }

    /// @notice UniV4 happy path using BSC StateView + byPoolKey (bypass PositionManager)
    function test_univ4_happyPath() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        address stateView = 0xd13Dd3D6E93f276FAfc9Db9E6BB47C1180aeE0c4;
        // Known pool on BSC — use byPoolKey to avoid PositionManager dependency
        // WBNB/USDT 0.25% pool: currency0=USDT, currency1=WBNB, fee=2500, tickSpacing=50
        IPositionManager.PoolKey memory poolkey = IPositionManager.PoolKey({
            currency0: IPositionManager.Currency.wrap(0x55d398326f99059fF775485246999027B3197955), // USDT
            currency1: IPositionManager.Currency.wrap(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c), // WBNB
            fee: 2500,
            tickSpacing: 50,
            hooks: IHooks(address(0))
        });
        bytes32 poolId = keccak256(abi.encode(poolkey));
        bytes memory data = QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactForNoPositionManager(poolId, 100, stateView, poolkey);
        uint256 tickCount = data.length / 32;
        console2.log("[UniV4-BSC byPoolKey] ticks found:", tickCount);
        validateTickData(data);
    }

    // ==================== PancakeInfinity — Happy Path (byPoolKey, no PositionManager) ====================

    /// @notice Test with the exact BSC ST/USDT pool that caused the 4/16 incident, using byPoolKey
    function test_pancakeInfinity_happyPath_ST_USDT_byPoolKey() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));

        // ST/USDT pool — the pool that triggered the 4/16 division-by-zero incident
        // This pool was NOT registered in PositionManager, which is why the old method failed
        ICLPoolManager.PoolKey memory poolKey = ICLPoolManager.PoolKey({
            currency0: 0x55d398326f99059fF775485246999027B3197955,  // USDT
            currency1: 0x70BE40667385500c5da7f108a022E21B606045DD,  // ST
            hooks:     0xb0BAa371b899950B4Ef6A27c21bAf5ef7c434d0f,
            poolManager: 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b,
            fee: 67,
            parameters: 0x00000000000000000000000000000000000000000000000000000000000a0045
        });

        bytes memory data = QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompactByPoolKey(poolKey, 100);
        uint256 tickCount = data.length / 32;
        console2.log("[PancakeInfinity byPoolKey] ST/USDT ticks found:", tickCount);
        assertTrue(tickCount > 0, "should find ticks for active pool");
        validateTickData(data);

        for (uint256 i = 0; i < 3 && i < tickCount; i++) {
            (int128 tick, int128 liq) = decodeTick(data, i);
            console2.log("  tick:", int256(tick));
            console2.log("  liquidityNet:", int256(liq));
        }
    }

    // ==================== PancakeInfinity — Error Handling ====================

    function test_pancakeInfinity_unregisteredPool_tickSpacingZero() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        vm.expectRevert("err_quoter_pancake_infinity_tickSpacing_zero");
        QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompact(bytes32(uint256(0xdead)), 100);
    }

    function test_pancakeInfinity_byPoolKey_zeroTickSpacing_reverts() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        ICLPoolManager.PoolKey memory badKey;
        badKey.parameters = bytes32(0);
        vm.expectRevert("err_quoter_pancake_infinity_tickSpacing_zero");
        QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompactByPoolKey(badKey, 100);
    }

    // ==================== PancakeInfinity LB — Error Handling ====================

    function test_pancakeLB_emptyPool_returnsZero() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        // LB Manager exists on BSC, fake poolId → getNextNonEmptyBin returns sentinel → (0,0)
        (uint256 rx, uint256 ry) = QueryPancakeInfinityLBReserveSuperCompact.queryPancakeInfinityLBReserve(bytes32(uint256(0x1)));
        assertEq(rx, 0, "empty pool should return 0 reserveX");
        assertEq(ry, 0, "empty pool should return 0 reserveY");
    }

    // Note: PancakeLB Manager exists on BSC, so calling with invalid poolId returns sentinel (0,0) — no revert.
    // We test the revert case on ETH where the hardcoded LB Manager address (0xC697d...) has no code.
    // On ETH, staticcall to that address returns (true, empty data) → abi.decode fails.
    // This is expected: the LB quoter is BSC-only. On other chains it will fail at the EVM level, not with err_quoter_ prefix.

    // ==================== Izumi — Error Handling ====================

    function test_izumi_notAPool_reverts_with_prefix() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        vm.expectRevert("err_quoter_izumi_pointDelta_failed");
        QueryIzumiSuperCompact.queryIzumiSuperCompact(USDC_BSC, 100);
    }

    // ==================== Horizon — Error Handling ====================

    function test_horizon_notAPool_reverts_with_prefix() public {
        vm.createSelectFork(vm.envOr("LINEA_RPC_URL", string("https://linea-rpc.publicnode.com")));
        vm.expectRevert("err_quoter_horizon_getPoolState_failed");
        QueryHorizonTicksSuperCompact.queryHorizonTicksSuperCompact(USDC_LINEA, 100);
    }

    // ==================== FluidDexV2D3D4 — Parameter Validation ====================

    function test_fluidDex_invalidDexType_reverts() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        vm.expectRevert("err_quoter_fluid_invalid_dex_type");
        QueryFluidDexV2D3D4.queryFluidDexV2D3D4TicksSuperCompact(USDC_ETH, 1, bytes32(0), 60, 100);
    }

    function test_fluidDex_tickSpacingZero_reverts() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        vm.expectRevert("err_quoter_fluid_tickSpacing_zero");
        QueryFluidDexV2D3D4.queryFluidDexV2D3D4TicksSuperCompact(USDC_ETH, 3, bytes32(0), 0, 100);
    }

    function test_fluidDex_invalidWordPosition_reverts() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        vm.expectRevert("err_quoter_fluid_invalid_word_position");
        QueryFluidDexV2D3D4.queryFluidDexV2D3D4TickBitmap(USDC_ETH, 3, bytes32(0), 10, 5);
    }

    // ==================== Error Prefix Consistency ====================

    function test_errorPrefix_univ3() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        try QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(USDC_ETH, 100) {
            fail("should revert");
        } catch Error(string memory reason) {
            assertTrue(_startsWith(reason, "err_quoter_"), string.concat("got: ", reason));
            console2.log("[UniV3] error:", reason);
        }
    }

    function test_errorPrefix_univ4() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        IPositionManager.PoolKey memory badKey = IPositionManager.PoolKey({
            currency0: IPositionManager.Currency.wrap(address(0)),
            currency1: IPositionManager.Currency.wrap(address(0x1)),
            fee: 500,
            tickSpacing: 0,
            hooks: IHooks(address(0))
        });
        try QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactForNoPositionManager(bytes32(uint256(1)), 100, USDC_BSC, badKey) {
            fail("should revert");
        } catch Error(string memory reason) {
            assertTrue(_startsWith(reason, "err_quoter_"), string.concat("got: ", reason));
            console2.log("[UniV4] error:", reason);
        }
    }

    function test_errorPrefix_algebra() public {
        vm.createSelectFork(vm.envOr("AVAX_RPC_URL", string("https://avalanche.drpc.org")));
        try QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact(USDC_AVAX, 100) {
            fail("should revert");
        } catch Error(string memory reason) {
            assertTrue(_startsWith(reason, "err_quoter_"), string.concat("got: ", reason));
            console2.log("[Algebra] error:", reason);
        }
    }

    function test_errorPrefix_izumi() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        try QueryIzumiSuperCompact.queryIzumiSuperCompact(USDC_BSC, 100) {
            fail("should revert");
        } catch Error(string memory reason) {
            assertTrue(_startsWith(reason, "err_quoter_"), string.concat("got: ", reason));
            console2.log("[Izumi] error:", reason);
        }
    }

    function test_errorPrefix_horizon() public {
        vm.createSelectFork(vm.envOr("LINEA_RPC_URL", string("https://linea-rpc.publicnode.com")));
        try QueryHorizonTicksSuperCompact.queryHorizonTicksSuperCompact(USDC_LINEA, 100) {
            fail("should revert");
        } catch Error(string memory reason) {
            assertTrue(_startsWith(reason, "err_quoter_"), string.concat("got: ", reason));
            console2.log("[Horizon] error:", reason);
        }
    }

    function test_errorPrefix_fluidDex() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        try QueryFluidDexV2D3D4.queryFluidDexV2D3D4TicksSuperCompact(USDC_ETH, 1, bytes32(0), 60, 100) {
            fail("should revert");
        } catch Error(string memory reason) {
            assertTrue(_startsWith(reason, "err_quoter_"), string.concat("got: ", reason));
            console2.log("[FluidDex] error:", reason);
        }
    }

    // ==================== Gas Benchmark ====================

    function test_gas_univ3_query() public {
        vm.createSelectFork(vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com")));
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint256 gasBefore = gasleft();
        bytes memory data = QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, 250);
        uint256 gasUsed = gasBefore - gasleft();
        uint256 tickCount = data.length / 32;
        console2.log("[Gas] UniV3 250 - gas:", gasUsed, "ticks:", tickCount);
        if (tickCount > 0) console2.log("[Gas] UniV3 per tick:", gasUsed / tickCount);
    }

    function test_gas_pancakeInfinity_query() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        ICLPoolManager.PoolKey memory poolKey = ICLPoolManager.PoolKey({
            currency0: 0x55d398326f99059fF775485246999027B3197955,
            currency1: 0x70BE40667385500c5da7f108a022E21B606045DD,
            hooks:     0xb0BAa371b899950B4Ef6A27c21bAf5ef7c434d0f,
            poolManager: 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b,
            fee: 67,
            parameters: 0x00000000000000000000000000000000000000000000000000000000000a0045
        });
        uint256 gasBefore = gasleft();
        bytes memory data = QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompactByPoolKey(poolKey, 250);
        uint256 gasUsed = gasBefore - gasleft();
        uint256 tickCount = data.length / 32;
        console2.log("[Gas] PancakeInfinity byPoolKey 250 - gas:", gasUsed, "ticks:", tickCount);
        if (tickCount > 0) console2.log("[Gas] PancakeInfinity per tick:", gasUsed / tickCount);
    }

    // ==================== Internal Helpers ====================

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory s = bytes(str);
        bytes memory p = bytes(prefix);
        if (s.length < p.length) return false;
        for (uint256 i = 0; i < p.length; i++) {
            if (s[i] != p[i]) return false;
        }
        return true;
    }
}
