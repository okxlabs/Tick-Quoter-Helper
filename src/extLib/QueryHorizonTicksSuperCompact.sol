// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interface/IAlgebraPool.sol";
import "../interface/ICLPoolManager.sol";
import "../interface/IHooks.sol";
import "../interface/IHorizonPool.sol";
import "../interface/IPoolManager.sol";
import "../interface/IPositionManager.sol";
import "../interface/IStateView.sol";
import "../interface/IUniswapV3Pool.sol";
import "../interface/IZora.sol";
import "../interface/IZumiPool.sol";

library QueryHorizonTicksSuperCompact {
    int24 internal constant MIN_TICK_MINUS_1 = -887_272 - 1;
    int24 internal constant MAX_TICK_PLUS_1 = 887_272 + 1;

    struct SuperVar {
        int24 tickSpacing;
        int24 currTick;
        int24 right;
        int24 left;
        int24 leftMost;
        int24 rightMost;
        uint256 initPoint;
        uint256 initPoint2;
    }

    function queryHorizonTicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        (bool gps, bytes memory gpsd) = pool.staticcall(abi.encodeWithSelector(IHorizonPool.getPoolState.selector));
        require(gps, "err_quoter_horizon_getPoolState_failed");
        (,, int24 currTick,) = abi.decode(gpsd, (uint160, int24, int24, bool));
        int24 currTick2 = currTick;
        uint256 threshold = len / 2;

        // travel from left to right
        // Pre-allocate to avoid O(n^2) bytes.concat; we will trim to actual length before return.
        bytes memory tickInfo = new bytes(len * 32);
        uint256 index = 0;

        while (currTick < MAX_TICK_PLUS_1 && len > threshold) {
            int128 liquidityNet;
            try IHorizonPool(pool).ticks(currTick) returns (uint128, int128 _liquidityNet, uint256, uint128) {
                liquidityNet = _liquidityNet;
            } catch {
                revert("err_quoter_horizon_ticks_failed");
            }

            int256 data = int256(uint256(int256(currTick)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            // Write packed bytes32 directly into the pre-allocated buffer.
            assembly {
                mstore(add(tickInfo, add(32, mul(index, 32))), data)
            }
            int24 nextTick;
            try IHorizonPool(pool).initializedTicks(currTick) returns (int24, int24 _nextTick) {
                nextTick = _nextTick;
            } catch {
                revert("err_quoter_horizon_initializedTicks_failed");
            }
            if (currTick == nextTick) {
                break;
            }
            currTick = nextTick;
            len--;
            index++;
        }

        while (currTick2 > MIN_TICK_MINUS_1 && len > 0) {
            int128 liquidityNet;
            try IHorizonPool(pool).ticks(currTick2) returns (uint128, int128 _liquidityNet, uint256, uint128) {
                liquidityNet = _liquidityNet;
            } catch {
                revert("err_quoter_horizon_ticks_failed");
            }
            int256 data = int256(uint256(int256(currTick2)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            // Write packed bytes32 directly into the pre-allocated buffer.
            assembly {
                mstore(add(tickInfo, add(32, mul(index, 32))), data)
            }
            int24 prevTick;
            try IHorizonPool(pool).initializedTicks(currTick2) returns (int24 _prevTick, int24) {
                prevTick = _prevTick;
            } catch {
                revert("err_quoter_horizon_initializedTicks_failed");
            }
            if (prevTick == currTick2) {
                break;
            }
            currTick2 = prevTick;
            len--;
            index++;
        }

        // Trim array to actual length (no empty content returned).
        assembly {
            mstore(tickInfo, mul(index, 32))
        }
        return tickInfo;
    }
}
