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
        (,, int24 currTick,) = IHorizonPool(pool).getPoolState();
        int24 currTick2 = currTick;
        uint256 threshold = len / 2;

        // travel from left to right
        // Pre-allocate to avoid O(n^2) bytes.concat; we will trim to actual length before return.
        bytes memory tickInfo = new bytes(len * 32);
        uint256 index = 0;

        while (currTick < MAX_TICK_PLUS_1 && len > threshold) {
            (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(currTick);

            int256 data = int256(uint256(int256(currTick)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            // Write packed bytes32 directly into the pre-allocated buffer.
            assembly {
                mstore(add(tickInfo, add(32, mul(index, 32))), data)
            }
            (, int24 nextTick) = IHorizonPool(pool).initializedTicks(currTick);
            if (currTick == nextTick) {
                break;
            }
            currTick = nextTick;
            len--;
            index++;
        }

        while (currTick2 > MIN_TICK_MINUS_1 && len > 0) {
            (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(currTick2);
            int256 data = int256(uint256(int256(currTick2)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            // Write packed bytes32 directly into the pre-allocated buffer.
            assembly {
                mstore(add(tickInfo, add(32, mul(index, 32))), data)
            }
            (int24 prevTick,) = IHorizonPool(pool).initializedTicks(currTick2);
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
