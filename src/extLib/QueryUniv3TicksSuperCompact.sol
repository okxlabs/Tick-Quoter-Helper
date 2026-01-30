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

    /// @notice Optimized version with pre-allocated array to avoid O(n²) bytes.concat
    /// @param pool The Uniswap V3 pool address
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryUniv3TicksSuperCompactAuto(address pool) public view returns (bytes memory) {
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

        // Pre-allocate fixed size array to avoid O(n²) bytes.concat
        bytes memory tickInfo = new bytes(MAX_TICKS * 32);
        uint256 tickCount = 0;

        tmp.left = tmp.right;

        // Alternating query: query right and left by word to balance tick range
        bool canQueryRight = true;
        bool canQueryLeft = true;
        bool isLeftInitPoint = true;

        while (gasleft() > GRC.calcGasReserve(tickCount) && (canQueryRight || canQueryLeft) && tickCount < MAX_TICKS) {
            // Query one word on the right side
            if (canQueryRight && tmp.right < tmp.rightMost && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS) {
                uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.right));
                if (res > 0) {
                    res = res >> tmp.initPoint;
                    for (uint256 i = tmp.initPoint; i < 256 && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS; i++) {
                        uint256 isInit = res & 0x01;
                        if (isInit > 0) {
                            int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);
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
                            // Write directly to pre-allocated memory position
                            assembly {
                                mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                            }
                            tickCount++;
                        }
                        res = res >> 1;
                    }
                }
                tmp.initPoint = 0;
                tmp.right++;
                canQueryRight = tmp.right < tmp.rightMost;
            } else {
                canQueryRight = false;
            }

            // Query one word on the left side
            if (canQueryLeft && tmp.left > tmp.leftMost && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS) {
                uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.left));
                if (res > 0 && tmp.initPoint2 != 0) {
                    res = isLeftInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                    for (uint256 i = tmp.initPoint2 - 1; i >= 0 && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS; i--) {
                        uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                        if (isInit > 0) {
                            int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);
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
                            // Write directly to pre-allocated memory position
                            assembly {
                                mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                            }
                            tickCount++;
                        }
                        res = res << 1;
                        if (i == 0) break;
                    }
                }
                isLeftInitPoint = false;
                tmp.initPoint2 = 256;
                tmp.left--;
                canQueryLeft = tmp.left > tmp.leftMost;
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
