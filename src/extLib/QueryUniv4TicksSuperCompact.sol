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

library QueryUniv4TicksSuperCompact {
    address public constant PANCAKE_INFINITY_CLPOOLMANAGER = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
    address public constant PANCAKE_INFINITY_POSITION_MANAGER = 0x55f4c8abA71A1e923edC303eb4fEfF14608cC226;
    uint256 internal constant OFFSET_TICK_SPACING = 16;

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

        bytes memory tickInfo;
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
                        tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

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
                        tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

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

        bytes memory tickInfo;
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
                        tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

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
                        tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

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

        bytes memory tickInfo;
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
                        tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

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
                        tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

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
}
