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

library QueryUniv4TicksSuperCompact {
    address public constant PANCAKE_INFINITY_CLPOOLMANAGER = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
    address public constant PANCAKE_INFINITY_POSITION_MANAGER = 0x55f4c8abA71A1e923edC303eb4fEfF14608cC226;
    uint256 internal constant OFFSET_TICK_SPACING = 16;
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

    function getTickSpacing(bytes32 params) internal pure returns (int24 tickSpacing) {
        assembly {
            tickSpacing := and(shr(OFFSET_TICK_SPACING, params), 0xffffff)
        }
    }

    function queryUniv4TicksSuperCompact(
        bytes32 poolId,
        uint256 len,
        address STATE_VIEW,
        address POSITION_MANAGER
    ) public view returns (bytes memory) {
        SuperVar memory tmp;
        IPositionManager.PoolKey memory poolkey = IPositionManager(POSITION_MANAGER).poolKeys(bytes25(poolId));
        tmp.tickSpacing = poolkey.tickSpacing;

        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) =
                IStateView(STATE_VIEW).getSlot0(statePoolId);
            tmp.currTick = tick;
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
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                        (uint128 liquidityGross, int128 liquidityNet) =
                            IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

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
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                        (uint128 liquidityGross, int128 liquidityNet) =
                            IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

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
        // Trim array to actual length (no empty content returned).
        assembly {
            mstore(tickInfo, mul(index, 32))
        }
        return tickInfo;
    }

    function queryUniv4TicksSuperCompactForNoPositionManager(
        bytes32 poolId,
        uint256 len,
        address STATE_VIEW,
        IPositionManager.PoolKey calldata poolkey
    ) public view returns (bytes memory) {
        SuperVar memory tmp;
        tmp.tickSpacing = poolkey.tickSpacing;

        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) =
                IStateView(STATE_VIEW).getSlot0(statePoolId);
            tmp.currTick = tick;
        }

        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position().
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
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                        (uint128 liquidityGross, int128 liquidityNet) =
                            IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

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
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                        (uint128 liquidityGross, int128 liquidityNet) =
                            IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

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
        // Trim array to actual length (no empty content returned).
        assembly {
            mstore(tickInfo, mul(index, 32))
        }
        return tickInfo;
    }

    function queryPancakeInfinityTicksSuperCompact(
        bytes32 poolId,
        uint256 len
    ) public view returns (bytes memory) {
        SuperVar memory tmp;

        {
            (, bytes memory result) = PANCAKE_INFINITY_POSITION_MANAGER.staticcall(
                abi.encodeWithSignature("poolKeys(bytes25)", bytes25(poolId))
            );
            bytes32 parameters;
            assembly {
                // Skip currency0 (32), currency1 (32), hooks (32), poolManager (32), fee (32)
                // Parameters is at offset 160 (32 * 5)
                parameters := mload(add(result, 192))
            }
            tmp.tickSpacing = getTickSpacing(parameters);
        }

        ICLPoolManager.PoolId clPoolId = ICLPoolManager.PoolId.wrap(poolId);

        {
            (, int24 tick,,) = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getSlot0(clPoolId);
            tmp.currTick = tick;
        }

        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position().
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
            uint256 res = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                        Tick.Info memory tickInfo_ = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolTickInfo(
                            clPoolId, int24(int256(tick))
                        );
                        int128 liquidityNet = tickInfo_.liquidityNet;

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
            uint256 res = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                        Tick.Info memory tickInfo_ = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolTickInfo(
                            clPoolId, int24(int256(tick))
                        );
                        int128 liquidityNet = tickInfo_.liquidityNet;

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
        // Trim array to actual length (no empty content returned).
        assembly {
            mstore(tickInfo, mul(index, 32))
        }
        return tickInfo;
    }

    /// @notice Query ticks on one side of currTick
    /// @param isLeft If true, query left side (excludes currTick); if false, query right side (includes currTick)
    function queryUniv4TicksSuperCompactOneSide(
        bytes32 poolId,
        address STATE_VIEW,
        address POSITION_MANAGER,
        bool isLeft
    ) public view returns (bytes memory) {
        OneSideVar memory v;
        v.tickSpacing = IPositionManager(POSITION_MANAGER).poolKeys(bytes25(poolId)).tickSpacing;
        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);
        (, v.currTick,,) = IStateView(STATE_VIEW).getSlot0(statePoolId);

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) compressed--;

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
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.wordPos);
            if (res > 0) {
                int256 i = v.bitPos;
                while (gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (isLeft ? i < 0 : i >= 256) break;
                    if ((res >> uint256(i)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.wordPos) + i) * v.tickSpacing);
                        (, int128 liquidityNet) = IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
                        v.tickCount++;
                    }
                    i = isLeft ? i - 1 : i + 1;
                }
            }
            v.wordPos = isLeft ? v.wordPos - 1 : v.wordPos + 1;
            v.bitPos = isLeft ? int256(255) : int256(0);
        }
        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") { mstore(tickInfo, mul(finalCount, 32)) }
        return tickInfo;
    }

    /// @notice Optimized version with tick-by-tick alternating query for balanced left/right distribution
    function queryUniv4TicksSuperCompactAuto(
        bytes32 poolId,
        address STATE_VIEW,
        address POSITION_MANAGER
    ) public view returns (bytes memory) {
        AutoVar memory v;
        v.tickSpacing = IPositionManager(POSITION_MANAGER).poolKeys(bytes25(poolId)).tickSpacing;
        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);
        (, v.currTick,,) = IStateView(STATE_VIEW).getSlot0(statePoolId);

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) compressed--;

        v.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        v.leftMost = int16(-887_272 / v.tickSpacing / int24(256) - 2);
        v.rightMost = int16(887_272 / v.tickSpacing / int24(256) + 1);

        bytes memory tickInfo = new bytes(MAX_TICKS * 32);

        // Right side state
        v.rWord = int16(compressed >> 8);
        v.rBit = int256(v.initPoint);
        v.rRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.rWord);
        v.rDone = v.rWord >= v.rightMost;

        // Left side state (start from initPoint - 1 to avoid duplicate with right)
        v.lWord = v.rWord;
        v.lBit = int256(v.initPoint) - 1;

        if (v.lBit < 0) {
            v.lWord--;
            v.lBit = 255;
            v.lDone = v.lWord <= v.leftMost;
        }
        if (!v.lDone) v.lRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.lWord);

        while ((!v.rDone || !v.lDone) && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
            // Find one tick on right
            if (!v.rDone) {
                bool found = false;
                while (!found && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (v.rBit >= 256) {
                        v.rWord++;
                        v.rBit = 0;
                        if (v.rWord >= v.rightMost) { v.rDone = true; break; }
                        v.rRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.rWord);
                    }
                    if ((v.rRes >> uint256(v.rBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.rWord) + v.rBit) * v.tickSpacing);
                        (, int128 liquidityNet) = IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
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
                        if (v.lWord <= v.leftMost) { v.lDone = true; break; }
                        v.lRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.lWord);
                    }
                    if ((v.lRes >> uint256(v.lBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.lWord) + v.lBit) * v.tickSpacing);
                        (, int128 liquidityNet) = IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
                        v.tickCount++;
                        found = true;
                    }
                    v.lBit--;
                }
            }
        }
        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") { mstore(tickInfo, mul(finalCount, 32)) }
        return tickInfo;
    }

    /// @notice Query ticks on one side of currTick for pools without position manager
    /// @param isLeft If true, query left side (excludes currTick); if false, query right side (includes currTick)
    function queryUniv4TicksSuperCompactForNoPositionManagerOneSide(
        bytes32 poolId,
        address STATE_VIEW,
        IPositionManager.PoolKey calldata poolkey,
        bool isLeft
    ) public view returns (bytes memory) {
        OneSideVar memory v;
        v.tickSpacing = poolkey.tickSpacing;
        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);
        (, v.currTick,,) = IStateView(STATE_VIEW).getSlot0(statePoolId);

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) compressed--;

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
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.wordPos);
            if (res > 0) {
                int256 i = v.bitPos;
                while (gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (isLeft ? i < 0 : i >= 256) break;
                    if ((res >> uint256(i)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.wordPos) + i) * v.tickSpacing);
                        (, int128 liquidityNet) = IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
                        v.tickCount++;
                    }
                    i = isLeft ? i - 1 : i + 1;
                }
            }
            v.wordPos = isLeft ? v.wordPos - 1 : v.wordPos + 1;
            v.bitPos = isLeft ? int256(255) : int256(0);
        }
        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") { mstore(tickInfo, mul(finalCount, 32)) }
        return tickInfo;
    }

    /// @notice Optimized version with tick-by-tick alternating query for pools without position manager
    function queryUniv4TicksSuperCompactForNoPositionManagerAuto(
        bytes32 poolId,
        address STATE_VIEW,
        IPositionManager.PoolKey calldata poolkey
    ) public view returns (bytes memory) {
        AutoVar memory v;
        v.tickSpacing = poolkey.tickSpacing;
        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);
        (, v.currTick,,) = IStateView(STATE_VIEW).getSlot0(statePoolId);

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) compressed--;

        v.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        v.leftMost = int16(-887_272 / v.tickSpacing / int24(256) - 2);
        v.rightMost = int16(887_272 / v.tickSpacing / int24(256) + 1);

        bytes memory tickInfo = new bytes(MAX_TICKS * 32);

        // Right side state
        v.rWord = int16(compressed >> 8);
        v.rBit = int256(v.initPoint);
        v.rRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.rWord);
        v.rDone = v.rWord >= v.rightMost;

        // Left side state (start from initPoint - 1 to avoid duplicate with right)
        v.lWord = v.rWord;
        v.lBit = int256(v.initPoint) - 1;

        if (v.lBit < 0) {
            v.lWord--;
            v.lBit = 255;
            v.lDone = v.lWord <= v.leftMost;
        }
        if (!v.lDone) v.lRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.lWord);

        while ((!v.rDone || !v.lDone) && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
            // Find one tick on right
            if (!v.rDone) {
                bool found = false;
                while (!found && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (v.rBit >= 256) {
                        v.rWord++;
                        v.rBit = 0;
                        if (v.rWord >= v.rightMost) { v.rDone = true; break; }
                        v.rRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.rWord);
                    }
                    if ((v.rRes >> uint256(v.rBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.rWord) + v.rBit) * v.tickSpacing);
                        (, int128 liquidityNet) = IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
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
                        if (v.lWord <= v.leftMost) { v.lDone = true; break; }
                        v.lRes = IStateView(STATE_VIEW).getTickBitmap(statePoolId, v.lWord);
                    }
                    if ((v.lRes >> uint256(v.lBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.lWord) + v.lBit) * v.tickSpacing);
                        (, int128 liquidityNet) = IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
                        v.tickCount++;
                        found = true;
                    }
                    v.lBit--;
                }
            }
        }
        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") { mstore(tickInfo, mul(finalCount, 32)) }
        return tickInfo;
    }

    /// @notice Query ticks on one side of currTick for Pancake Infinity pools
    /// @param isLeft If true, query left side (excludes currTick); if false, query right side (includes currTick)
    function queryPancakeInfinityTicksSuperCompactOneSide(
        bytes32 poolId,
        bool isLeft
    ) public view returns (bytes memory) {
        OneSideVar memory v;
        {
            (, bytes memory result) = PANCAKE_INFINITY_POSITION_MANAGER.staticcall(
                abi.encodeWithSignature("poolKeys(bytes25)", bytes25(poolId))
            );
            bytes32 parameters;
            assembly ("memory-safe") { parameters := mload(add(result, 192)) }
            v.tickSpacing = getTickSpacing(parameters);
        }

        ICLPoolManager.PoolId clPoolId = ICLPoolManager.PoolId.wrap(poolId);
        (, v.currTick,,) = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getSlot0(clPoolId);

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) compressed--;

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
            uint256 res = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, v.wordPos);
            if (res > 0) {
                int256 i = v.bitPos;
                while (gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (isLeft ? i < 0 : i >= 256) break;
                    if ((res >> uint256(i)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.wordPos) + i) * v.tickSpacing);
                        Tick.Info memory tickInfo_ = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolTickInfo(clPoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(tickInfo_.liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
                        v.tickCount++;
                    }
                    i = isLeft ? i - 1 : i + 1;
                }
            }
            v.wordPos = isLeft ? v.wordPos - 1 : v.wordPos + 1;
            v.bitPos = isLeft ? int256(255) : int256(0);
        }
        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") { mstore(tickInfo, mul(finalCount, 32)) }
        return tickInfo;
    }

    /// @notice Optimized version with tick-by-tick alternating query for Pancake Infinity pools
    function queryPancakeInfinityTicksSuperCompactAuto(
        bytes32 poolId
    ) public view returns (bytes memory) {
        AutoVar memory v;
        {
            (, bytes memory result) = PANCAKE_INFINITY_POSITION_MANAGER.staticcall(
                abi.encodeWithSignature("poolKeys(bytes25)", bytes25(poolId))
            );
            bytes32 parameters;
            assembly ("memory-safe") { parameters := mload(add(result, 192)) }
            v.tickSpacing = getTickSpacing(parameters);
        }

        ICLPoolManager.PoolId clPoolId = ICLPoolManager.PoolId.wrap(poolId);
        (, v.currTick,,) = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getSlot0(clPoolId);

        int24 compressed = v.currTick / v.tickSpacing;
        if (v.currTick < 0 && (v.currTick % v.tickSpacing != 0)) compressed--;

        v.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        v.leftMost = int16(-887_272 / v.tickSpacing / int24(256) - 2);
        v.rightMost = int16(887_272 / v.tickSpacing / int24(256) + 1);

        bytes memory tickInfo = new bytes(MAX_TICKS * 32);

        // Right side state
        v.rWord = int16(compressed >> 8);
        v.rBit = int256(v.initPoint);
        v.rRes = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, v.rWord);
        v.rDone = v.rWord >= v.rightMost;

        // Left side state (start from initPoint - 1 to avoid duplicate with right)
        v.lWord = v.rWord;
        v.lBit = int256(v.initPoint) - 1;

        if (v.lBit < 0) {
            v.lWord--;
            v.lBit = 255;
            v.lDone = v.lWord <= v.leftMost;
        }
        if (!v.lDone) v.lRes = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, v.lWord);

        while ((!v.rDone || !v.lDone) && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
            // Find one tick on right
            if (!v.rDone) {
                bool found = false;
                while (!found && gasleft() > GRC.calcGasReserve(v.tickCount) && v.tickCount < MAX_TICKS) {
                    if (v.rBit >= 256) {
                        v.rWord++;
                        v.rBit = 0;
                        if (v.rWord >= v.rightMost) { v.rDone = true; break; }
                        v.rRes = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, v.rWord);
                    }
                    if ((v.rRes >> uint256(v.rBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.rWord) + v.rBit) * v.tickSpacing);
                        Tick.Info memory tickInfo_ = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolTickInfo(clPoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(tickInfo_.liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
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
                        if (v.lWord <= v.leftMost) { v.lDone = true; break; }
                        v.lRes = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, v.lWord);
                    }
                    if ((v.lRes >> uint256(v.lBit)) & 1 == 1) {
                        int256 tick = int256((256 * int256(v.lWord) + v.lBit) * v.tickSpacing);
                        Tick.Info memory tickInfo_ = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolTickInfo(clPoolId, int24(int256(tick)));
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(tickInfo_.liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        uint256 tc = v.tickCount;
                        assembly ("memory-safe") { mstore(add(tickInfo, add(32, mul(tc, 32))), data) }
                        v.tickCount++;
                        found = true;
                    }
                    v.lBit--;
                }
            }
        }
        uint256 finalCount = v.tickCount;
        assembly ("memory-safe") { mstore(tickInfo, mul(finalCount, 32)) }
        return tickInfo;
    }
}
