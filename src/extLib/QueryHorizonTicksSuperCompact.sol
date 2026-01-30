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

import {GasReserveCalcLib as GRC} from "./GasReserveCalcLib.sol";

library QueryHorizonTicksSuperCompact {
    int24 internal constant MIN_TICK_MINUS_1 = -887_272 - 1;
    int24 internal constant MAX_TICK_PLUS_1 = 887_272 + 1;
    uint256 internal constant MAX_TICKS = 4000;

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

    /// @notice Optimized auto version with gas-based termination and alternating query
    /// @param pool The Horizon pool address
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryHorizonTicksSuperCompactAuto(address pool) public view returns (bytes memory) {
        (,, int24 currTick,) = IHorizonPool(pool).getPoolState();
        int24 rightTick = currTick;
        int24 leftTick = currTick;

        // Pre-allocate fixed size array to avoid O(n²) bytes.concat
        bytes memory tickInfo = new bytes(MAX_TICKS * 32);
        uint256 tickCount = 0;

        // Alternating query: query right and left to balance tick range
        bool canQueryRight = true;
        bool canQueryLeft = true;

        while (gasleft() > GRC.calcGasReserve(tickCount) && (canQueryRight || canQueryLeft) && tickCount < MAX_TICKS) {
            // Query one tick on the right side
            if (canQueryRight && rightTick < MAX_TICK_PLUS_1 && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS) {
                (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(rightTick);

                int256 data = int256(uint256(int256(rightTick)) << 128)
                    + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                // Write packed bytes32 directly into the pre-allocated buffer.
                assembly {
                    mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                }
                tickCount++;

                (, int24 nextTick) = IHorizonPool(pool).initializedTicks(rightTick);
                if (rightTick == nextTick) {
                    canQueryRight = false;
                } else {
                    rightTick = nextTick;
                }
            } else {
                canQueryRight = false;
            }

            // Query one tick on the left side
            if (canQueryLeft && leftTick > MIN_TICK_MINUS_1 && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS) {
                (int24 prevTick,) = IHorizonPool(pool).initializedTicks(leftTick);
                if (prevTick == leftTick) {
                    canQueryLeft = false;
                } else {
                    leftTick = prevTick;

                    (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(leftTick);
                    int256 data = int256(uint256(int256(leftTick)) << 128)
                        + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                    // Write packed bytes32 directly into the pre-allocated buffer.
                    assembly {
                        mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                    }
                    tickCount++;
                }
            } else {
                canQueryLeft = false;
            }
        }

        // Trim array to actual length (no empty content returned)
        assembly {
            mstore(tickInfo, mul(tickCount, 32))
        }
        return tickInfo;
    }
}
