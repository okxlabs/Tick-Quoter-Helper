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
        (bool pk, bytes memory pkd) = POSITION_MANAGER.staticcall(abi.encodeWithSelector(IPositionManager.poolKeys.selector, bytes25(poolId)));
        require(pk, "err_quoter_univ4_poolKeys_failed");
        IPositionManager.PoolKey memory poolkey = abi.decode(pkd, (IPositionManager.PoolKey));
        tmp.tickSpacing = poolkey.tickSpacing;
        require(tmp.tickSpacing != 0, "err_quoter_univ4_tickSpacing_zero");

        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (bool gs, bytes memory gsd) = STATE_VIEW.staticcall(abi.encodeWithSelector(IStateView.getSlot0.selector, statePoolId));
            require(gs, "err_quoter_univ4_getSlot0_failed");
            (, int24 tick,,) = abi.decode(gsd, (uint160, int24, uint24, uint24));
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
            uint256 res;
            try IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.right)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_univ4_getTickBitmap_failed");
            }
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                        int128 liquidityNet;
                        try IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick))) returns (uint128, int128 _liquidityNet) {
                            liquidityNet = _liquidityNet;
                        } catch {
                            revert("err_quoter_univ4_getTickLiquidity_failed");
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
            uint256 res;
            try IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.left)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_univ4_getTickBitmap_failed");
            }
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                        int128 liquidityNet;
                        try IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick))) returns (uint128, int128 _liquidityNet) {
                            liquidityNet = _liquidityNet;
                        } catch {
                            revert("err_quoter_univ4_getTickLiquidity_failed");
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
        require(tmp.tickSpacing != 0, "err_quoter_univ4_tickSpacing_zero");

        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (bool gs0, bytes memory gsd0) = STATE_VIEW.staticcall(abi.encodeWithSelector(IStateView.getSlot0.selector, statePoolId));
            require(gs0, "err_quoter_univ4_getSlot0_failed");
            (, int24 tick,,) = abi.decode(gsd0, (uint160, int24, uint24, uint24));
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
            uint256 res;
            try IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.right)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_univ4_getTickBitmap_failed");
            }
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                        int128 liquidityNet;
                        try IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick))) returns (uint128, int128 _liquidityNet) {
                            liquidityNet = _liquidityNet;
                        } catch {
                            revert("err_quoter_univ4_getTickLiquidity_failed");
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
            uint256 res;
            try IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.left)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_univ4_getTickBitmap_failed");
            }
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                        int128 liquidityNet;
                        try IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick))) returns (uint128, int128 _liquidityNet) {
                            liquidityNet = _liquidityNet;
                        } catch {
                            revert("err_quoter_univ4_getTickLiquidity_failed");
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
        int24 tickSpacing;
        {
            (bool success, bytes memory result) = PANCAKE_INFINITY_POSITION_MANAGER.staticcall(
                abi.encodeWithSignature("poolKeys(bytes25)", bytes25(poolId))
            );
            require(success, "err_quoter_pancake_infinity_poolKeys_failed");
            bytes32 parameters;
            assembly {
                // bytes memory length prefix (32) + currency0 (32) + currency1 (32) + hooks (32) + poolManager (32) + fee (32)
                // Parameters is at offset 192 (32 * 6)
                parameters := mload(add(result, 192))
            }
            tickSpacing = getTickSpacing(parameters);
            require(tickSpacing != 0, "err_quoter_pancake_infinity_tickSpacing_zero");
        }
        return _queryPancakeInfinityTicksInternal(poolId, tickSpacing, len);
    }

    function queryPancakeInfinityTicksSuperCompactByPoolKey(
        ICLPoolManager.PoolKey calldata poolKey,
        uint256 len
    ) public view returns (bytes memory) {
        int24 tickSpacing = getTickSpacing(poolKey.parameters);
        require(tickSpacing != 0, "err_quoter_pancake_infinity_tickSpacing_zero");
        bytes32 poolId = keccak256(abi.encode(poolKey));
        return _queryPancakeInfinityTicksInternal(poolId, tickSpacing, len);
    }

    function _queryPancakeInfinityTicksInternal(
        bytes32 poolId,
        int24 tickSpacing,
        uint256 len
    ) private view returns (bytes memory) {
        SuperVar memory tmp;
        tmp.tickSpacing = tickSpacing;

        ICLPoolManager.PoolId clPoolId = ICLPoolManager.PoolId.wrap(poolId);

        {
            (bool pgs, bytes memory pgsd) = PANCAKE_INFINITY_CLPOOLMANAGER.staticcall(abi.encodeWithSelector(ICLPoolManager.getSlot0.selector, clPoolId));
            require(pgs, "err_quoter_pancake_infinity_getSlot0_failed");
            (, int24 tick,,) = abi.decode(pgsd, (uint160, int24, uint24, uint24));
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
            uint256 res;
            try ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, int16(tmp.right)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_pancake_infinity_getPoolBitmapInfo_failed");
            }
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                        try ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolTickInfo(clPoolId, int24(int256(tick))) returns (Tick.Info memory tickInfo_) {
                            int128 liquidityNet = tickInfo_.liquidityNet;

                            int256 data = int256(uint256(int256(tick)) << 128)
                                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                            // Write packed bytes32 directly into the pre-allocated buffer.
                            assembly {
                                mstore(add(tickInfo, add(32, mul(index, 32))), data)
                            }

                            index++;
                        } catch {
                            revert("err_quoter_pancake_infinity_getPoolTickInfo_failed");
                        }
                    }

                    res = res >> 1;
                }
            }
            tmp.initPoint = 0;
            tmp.right++;
        }

        bool isInitPoint = true;
        while (index < len && tmp.left > tmp.leftMost) {
            uint256 res;
            try ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolBitmapInfo(clPoolId, int16(tmp.left)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_pancake_infinity_getPoolBitmapInfo_failed");
            }
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                        try ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getPoolTickInfo(clPoolId, int24(int256(tick))) returns (Tick.Info memory tickInfo_) {
                            int128 liquidityNet = tickInfo_.liquidityNet;

                            int256 data = int256(uint256(int256(tick)) << 128)
                                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                            // Write packed bytes32 directly into the pre-allocated buffer.
                            assembly {
                                mstore(add(tickInfo, add(32, mul(index, 32))), data)
                            }

                            index++;
                        } catch {
                            revert("err_quoter_pancake_infinity_getPoolTickInfo_failed");
                        }
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
}
