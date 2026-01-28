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

library QueryUniv3TicksSuperCompact {
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

        bytes memory tickInfo;

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

    function queryUniv3TicksSuperCompactAuto(address pool, uint256 gasReserve) public view returns (bytes memory) {
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

        // Separate storage for right and left ticks to maintain order
        bytes memory rightTickInfo;
        bytes memory leftTickInfo;

        tmp.left = tmp.right;

        // Alternating query: query right and left by word to balance tick range
        bool canQueryRight = true;
        bool canQueryLeft = true;
        bool isLeftInitPoint = true;

        while (gasleft() > gasReserve && (canQueryRight || canQueryLeft)) {
            // Query one word on the right side
            if (canQueryRight && tmp.right < tmp.rightMost && gasleft() > gasReserve) {
                uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.right));
                if (res > 0) {
                    res = res >> tmp.initPoint;
                    for (uint256 i = tmp.initPoint; i < 256 && gasleft() > gasReserve; i++) {
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
                            rightTickInfo = bytes.concat(rightTickInfo, bytes32(uint256(data)));
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
            if (canQueryLeft && tmp.left > tmp.leftMost && gasleft() > gasReserve) {
                uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.left));
                if (res > 0 && tmp.initPoint2 != 0) {
                    res = isLeftInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                    for (uint256 i = tmp.initPoint2 - 1; i >= 0 && gasleft() > gasReserve; i--) {
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
                            leftTickInfo = bytes.concat(leftTickInfo, bytes32(uint256(data)));
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
        
        // Combine: right ticks first, then left ticks (same order as original)
        return bytes.concat(rightTickInfo, leftTickInfo);
    }

    /// @notice Optimized version with pre-allocated array to avoid O(n²) bytes.concat
    /// @param pool The Uniswap V3 pool address
    /// @param gasReserve Gas to reserve for return operations
    /// @param maxTicks Maximum number of ticks to query (used for pre-allocation)
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryUniv3TicksSuperCompactAuto2(address pool, uint256 gasReserve, uint256 maxTicks) public view returns (bytes memory) {
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
        bytes memory tickInfo = new bytes(maxTicks * 32);
        uint256 tickCount = 0;

        tmp.left = tmp.right;

        // Alternating query: query right and left by word to balance tick range
        bool canQueryRight = true;
        bool canQueryLeft = true;
        bool isLeftInitPoint = true;

        while (gasleft() > gasReserve && (canQueryRight || canQueryLeft) && tickCount < maxTicks) {
            // Query one word on the right side
            if (canQueryRight && tmp.right < tmp.rightMost && gasleft() > gasReserve && tickCount < maxTicks) {
                uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.right));
                if (res > 0) {
                    res = res >> tmp.initPoint;
                    for (uint256 i = tmp.initPoint; i < 256 && gasleft() > gasReserve && tickCount < maxTicks; i++) {
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
            if (canQueryLeft && tmp.left > tmp.leftMost && gasleft() > gasReserve && tickCount < maxTicks) {
                uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(tmp.left));
                if (res > 0 && tmp.initPoint2 != 0) {
                    res = isLeftInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                    for (uint256 i = tmp.initPoint2 - 1; i >= 0 && gasleft() > gasReserve && tickCount < maxTicks; i--) {
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
