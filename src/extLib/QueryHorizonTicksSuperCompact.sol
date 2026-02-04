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
    uint256 internal constant MAX_TICKS = 2500;

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

    struct OneSideVar {
        int24 tick;
        uint256 tickCount;
    }

    struct AutoVar {
        int24 rightTick;
        int24 leftTick;
        uint256 tickCount;
        bool canQueryRight;
        bool canQueryLeft;
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

    /// @notice Query ticks on one side of currTick
    /// @param pool The Horizon pool address
    /// @param isLeft If true, query left side (excludes currTick); if false, query right side (includes currTick)
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryHorizonTicksSuperCompactOneSide(address pool, bool isLeft) public view returns (bytes memory) {
        OneSideVar memory v;
        (,, v.tick,) = IHorizonPool(pool).getPoolState();

        bytes memory tickInfo = new bytes(MAX_TICKS * 32);

        if (isLeft) {
            // Query left side excluding currTick (to avoid duplicate with right side)
            // First move to the previous tick
            (int24 prevTick,) = IHorizonPool(pool).initializedTicks(v.tick);
            if (prevTick == v.tick) {
                // No previous tick, return empty
                assembly ("memory-safe") {
                    mstore(tickInfo, 0)
                }
                return tickInfo;
            }
            v.tick = prevTick;

            while (v.tick > MIN_TICK_MINUS_1 && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(v.tick);
                int256 data = int256(uint256(int256(v.tick)) << 128)
                    + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                uint256 tc = v.tickCount;
                assembly ("memory-safe") {
                    mstore(add(tickInfo, add(32, mul(tc, 32))), data)
                }
                v.tickCount++;

                (prevTick,) = IHorizonPool(pool).initializedTicks(v.tick);
                if (prevTick == v.tick) break;
                v.tick = prevTick;
            }
        } else {
            // Query right side including currTick
            while (v.tick < MAX_TICK_PLUS_1 && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(v.tick);
                int256 data = int256(uint256(int256(v.tick)) << 128)
                    + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                uint256 tc = v.tickCount;
                assembly ("memory-safe") {
                    mstore(add(tickInfo, add(32, mul(tc, 32))), data)
                }
                v.tickCount++;

                (, int24 nextTick) = IHorizonPool(pool).initializedTicks(v.tick);
                if (nextTick == v.tick) break;
                v.tick = nextTick;
            }
        }

        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") {
            mstore(tickInfo, mul(finalCount, 32))
        }
        return tickInfo;
    }

    /// @notice Optimized auto version with tick-by-tick alternating query for balanced left/right distribution
    /// @param pool The Horizon pool address
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryHorizonTicksSuperCompactAuto(address pool) public view returns (bytes memory) {
        AutoVar memory v;
        (,, v.rightTick,) = IHorizonPool(pool).getPoolState();
        v.leftTick = v.rightTick;
        v.canQueryRight = true;
        v.canQueryLeft = true;

        bytes memory tickInfo = new bytes(MAX_TICKS * 32);

        while (gasleft() > GRC.calcGasReserve(v.tickCount) && (v.canQueryRight || v.canQueryLeft) && v.tickCount < MAX_TICKS) {
            // Query one tick on the right side (includes currTick on first iteration)
            if (v.canQueryRight && v.rightTick < MAX_TICK_PLUS_1 && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(v.rightTick);
                int256 data = int256(uint256(int256(v.rightTick)) << 128)
                    + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                uint256 tc = v.tickCount;
                assembly ("memory-safe") {
                    mstore(add(tickInfo, add(32, mul(tc, 32))), data)
                }
                v.tickCount++;

                (, int24 nextTick) = IHorizonPool(pool).initializedTicks(v.rightTick);
                if (v.rightTick == nextTick) {
                    v.canQueryRight = false;
                } else {
                    v.rightTick = nextTick;
                }
            } else {
                v.canQueryRight = false;
            }

            // Query one tick on the left side (skip currTick to avoid duplicate with right)
            if (v.canQueryLeft && v.leftTick > MIN_TICK_MINUS_1 && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                (int24 prevTick,) = IHorizonPool(pool).initializedTicks(v.leftTick);
                if (prevTick == v.leftTick) {
                    v.canQueryLeft = false;
                } else {
                    v.leftTick = prevTick;
                    (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(v.leftTick);
                    int256 data = int256(uint256(int256(v.leftTick)) << 128)
                        + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                    uint256 tc = v.tickCount;
                    assembly ("memory-safe") {
                        mstore(add(tickInfo, add(32, mul(tc, 32))), data)
                    }
                    v.tickCount++;
                }
            } else {
                v.canQueryLeft = false;
            }
        }

        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") {
            mstore(tickInfo, mul(finalCount, 32))
        }
        return tickInfo;
    }
}
