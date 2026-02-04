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

library QueryUniv3TicksSuperCompact {
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
        int24 tickSpacing;
        int24 currTick;
        int16 wordPos;
        int256 bitPos;
        int16 wordLimit;
        uint256 tickCount;
    }

    struct AutoVar {
        int24 tickSpacing;
        int24 currTick;
        int16 leftMost;
        int16 rightMost;
        uint256 initPoint;
        int16 rWord;
        int256 rBit;
        uint256 rRes;
        bool rDone;
        int16 lWord;
        int256 lBit;
        uint256 lRes;
        bool lDone;
        uint256 tickCount;
    }

    function queryUniv3TicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        SuperVar memory tmp;
        tmp.tickSpacing = IUniswapV3Pool(pool).tickSpacing();
        // fix-bug: pancake pool's slot returns different types of params than uniV3, which will cause problem
        {
            (, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("slot0()"));
            int24 currTick;
            assembly {
                currTick := mload(add(slot0, 64))
            }
            tmp.currTick = currTick;
        }

        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position().
        // NOTE: Solidity division truncates toward zero, so negative ticks need floor adjustment.
        int24 compressed = tmp.currTick / tmp.tickSpacing;
        if (tmp.currTick < 0 && (tmp.currTick % tmp.tickSpacing != 0)) {
            compressed--;
        }
        tmp.right = compressed >> 8;
        tmp.leftMost = -887_272 / tmp.tickSpacing / int24(256) - 2;
        tmp.rightMost = 887_272 / tmp.tickSpacing / int24(256) + 1;

        tmp.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        tmp.initPoint2 = tmp.initPoint;

        // Pre-allocate to avoid O(n^2) bytes.concat; we will trim to actual length before return.
        bytes memory tickInfo = new bytes(len * 32);

        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);
                        // (, int128 liquidityNet,,,,,,) = IUniswapV3Pool(pool).ticks(int24(int256(tick)));
                        // fix-bug: to make consistent with solidlyV3 and ramsesV2
                        int128 liquidityNet;
                        (, bytes memory d) = pool.staticcall(
                            abi.encodeWithSelector(IUniswapV3PoolState.ticks.selector, int24(int256(tick)))
                        );
                        assembly {
                            liquidityNet := mload(add(d, 64))
                        }
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        // Write packed bytes32 directly into the pre-allocated buffer.
                        assembly {
                            mstore(add(tickInfo, add(32, mul(index, 32))), data)
                        }

                        index++;
                    }

                    res = res >> 1;
                }
            }
            tmp.initPoint = 0;
            tmp.right++;
        }
        bool isInitPoint = true;
        while (index < len && tmp.left > tmp.leftMost) {
            uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);
                        // (, int128 liquidityNet,,,,,,) = IUniswapV3Pool(pool).ticks(int24(int256(tick)));
                        // fix-bug: to make consistent with solidlyV3 and ramsesV2
                        int128 liquidityNet;
                        (, bytes memory d) = pool.staticcall(
                            abi.encodeWithSelector(IUniswapV3PoolState.ticks.selector, int24(int256(tick)))
                        );
                        assembly {
                            liquidityNet := mload(add(d, 64))
                        }
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        // Write packed bytes32 directly into the pre-allocated buffer.
                        assembly {
                            mstore(add(tickInfo, add(32, mul(index, 32))), data)
                        }

                        index++;
                    }

                    res = res << 1;
                    if (i == 0) break;
                }

            }
            isInitPoint = false;
            tmp.initPoint2 = 256;

            tmp.left--;
        }
        return tickInfo;
    }

    /// @notice Query ticks on one side of currTick
    /// @param pool The Uniswap V3 pool address
    /// @param isLeft If true, query left side (smaller ticks, excludes currTick); if false, query right side (larger ticks, includes currTick)
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryUniv3TicksSuperCompactOneSide(address pool, bool isLeft) public view returns (bytes memory) {
        OneSideVar memory v;
        v.tickSpacing = IUniswapV3Pool(pool).tickSpacing();
        {
            (, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("slot0()"));
            assembly ("memory-safe") {
                mstore(add(v, 32), mload(add(slot0, 64))) // v.currTick
            }
        }

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) {
            compressed--;
        }

        v.wordPos = int16(compressed >> 8);
        v.wordLimit = isLeft
            ? int16(-887_272 / v.tickSpacing / int24(256) - 2)
            : int16(887_272 / v.tickSpacing / int24(256) + 1);

        // For right side: start from compressed position (includes currTick area)
        // For left side: start from compressed - 1 (excludes currTick area to avoid duplicate)
        if (isLeft) {
            v.bitPos = int256(uint256(int256(compressed)) & 0xff) - 1;
            if (v.bitPos < 0) {
                v.wordPos--;
                v.bitPos = 255;
            }
        } else {
            v.bitPos = int256(uint256(int256(compressed)) & 0xff);
        }

        bytes memory tickInfo = new bytes(MAX_TICKS * 32);

        while (gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
            if (isLeft ? v.wordPos <= v.wordLimit : v.wordPos >= v.wordLimit) break;

            uint256 res = IUniswapV3Pool(pool).tickBitmap(v.wordPos);
            if (res > 0) {
                int256 i = v.bitPos;
                while (gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (isLeft ? i < 0 : i >= 256) break;
                    if ((res >> uint256(i)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.wordPos) + i) * v.tickSpacing);
                        int128 liquidityNet;
                        (, bytes memory d) = pool.staticcall(
                            abi.encodeWithSelector(IUniswapV3PoolState.ticks.selector, int24(int256(tick)))
                        );
                        assembly ("memory-safe") {
                            liquidityNet := mload(add(d, 64))
                        }
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") {
                            mstore(add(tickInfo, add(32, mul(tc, 32))), data)
                        }
                        v.tickCount++;
                    }
                    i = isLeft ? i - 1 : i + 1;
                }
            }
            v.wordPos = isLeft ? v.wordPos - 1 : v.wordPos + 1;
            v.bitPos = isLeft ? int256(255) : int256(0);
        }

        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") {
            mstore(tickInfo, mul(finalCount, 32))
        }
        return tickInfo;
    }

    /// @notice Optimized version with tick-by-tick alternating query for balanced left/right distribution
    /// @param pool The Uniswap V3 pool address
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryUniv3TicksSuperCompactAuto(address pool) public view returns (bytes memory) {
        AutoVar memory v;
        v.tickSpacing = IUniswapV3Pool(pool).tickSpacing();
        {
            (, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("slot0()"));
            assembly ("memory-safe") {
                mstore(add(v, 32), mload(add(slot0, 64))) // v.currTick
            }
        }

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) {
            compressed--;
        }

        v.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        v.leftMost = int16(-887_272 / v.tickSpacing / int24(256) - 2);
        v.rightMost = int16(887_272 / v.tickSpacing / int24(256) + 1);

        bytes memory tickInfo = new bytes(MAX_TICKS * 32);

        // Right side state
        v.rWord = int16(compressed >> 8);
        v.rBit = int256(v.initPoint);
        v.rRes = IUniswapV3Pool(pool).tickBitmap(v.rWord);
        v.rDone = v.rWord >= v.rightMost;

        // Left side state (start from initPoint - 1 to avoid duplicate with right)
        v.lWord = v.rWord;
        v.lBit = int256(v.initPoint) - 1;

        if (v.lBit < 0) {
            v.lWord--;
            v.lBit = 255;
            v.lDone = v.lWord <= v.leftMost;
        }
        if (!v.lDone) {
            v.lRes = IUniswapV3Pool(pool).tickBitmap(v.lWord);
        }

        while ((!v.rDone || !v.lDone) && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
            // Find one tick on right
            if (!v.rDone) {
                bool found = false;
                while (!found && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (v.rBit >= 256) {
                        v.rWord++;
                        v.rBit = 0;
                        if (v.rWord >= v.rightMost) {
                            v.rDone = true;
                            break;
                        }
                        v.rRes = IUniswapV3Pool(pool).tickBitmap(v.rWord);
                    }
                    if ((v.rRes >> uint256(v.rBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.rWord) + v.rBit) * v.tickSpacing);
                        int128 liquidityNet;
                        (, bytes memory d) = pool.staticcall(
                            abi.encodeWithSelector(IUniswapV3PoolState.ticks.selector, int24(int256(tick)))
                        );
                        assembly ("memory-safe") {
                            liquidityNet := mload(add(d, 64))
                        }
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") {
                            mstore(add(tickInfo, add(32, mul(tc, 32))), data)
                        }
                        v.tickCount++;
                        found = true;
                    }
                    v.rBit++;
                }
            }

            // Find one tick on left
            if (!v.lDone && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                bool found = false;
                while (!found && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (v.lBit < 0) {
                        v.lWord--;
                        v.lBit = 255;
                        if (v.lWord <= v.leftMost) {
                            v.lDone = true;
                            break;
                        }
                        v.lRes = IUniswapV3Pool(pool).tickBitmap(v.lWord);
                    }
                    if ((v.lRes >> uint256(v.lBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.lWord) + v.lBit) * v.tickSpacing);
                        int128 liquidityNet;
                        (, bytes memory d) = pool.staticcall(
                            abi.encodeWithSelector(IUniswapV3PoolState.ticks.selector, int24(int256(tick)))
                        );
                        assembly ("memory-safe") {
                            liquidityNet := mload(add(d, 64))
                        }
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") {
                            mstore(add(tickInfo, add(32, mul(tc, 32))), data)
                        }
                        v.tickCount++;
                        found = true;
                    }
                    v.lBit--;
                }
            }
        }

        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") {
            mstore(tickInfo, mul(finalCount, 32))
        }
        return tickInfo;
    }
}
