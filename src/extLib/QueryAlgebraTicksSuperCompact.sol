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

/**
 * @title QueryAlgebraTicksSuperCompact
 * @notice Query tick data from Algebra pools. Each tick encoded as 32 bytes (tick << 128 | liquidityNet).
 */
library QueryAlgebraTicksSuperCompact {
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

    /// @notice Algebra V1.9 pools - tick bitmap query, tickSpacing=1, full range scan
    function queryAlgebraTicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        SuperVar memory tmp;

        {
            (, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("globalState()"));
            int24 currTick;
            assembly {
                currTick := mload(add(slot0, 64))
            }
            tmp.currTick = currTick;
        }
        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position()
        // (tickSpacing=1 in this function).
        int24 compressed = tmp.currTick;
        tmp.right = compressed >> 8;
        tmp.leftMost = -887_272 / int24(256) - 2;
        tmp.rightMost = 887_272 / int24(256) + 1;

        tmp.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        tmp.initPoint2 = tmp.initPoint;

        bytes memory tickInfo;

        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res = IAlgebraPoolV1_9(pool).tickTable(int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)));
                        // (, int128 liquidityNet,,,,,,) = IAlgebraPoolV1_9(pool).ticks(int24(int256(tick)));
                        (, bytes memory deltaL) = pool.staticcall(abi.encodeWithSignature("ticks(int24)", tick));
                        int128 liquidityNet;
                        assembly {
                            liquidityNet := mload(add(deltaL, 64))
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
            uint256 res = IAlgebraPoolV1_9(pool).tickTable(int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;

                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)));
                        // (, int128 liquidityNet,,,,,,) = IAlgebraPoolV1_9(pool).ticks(int24(int256(tick)));

                        (, bytes memory deltaL) = pool.staticcall(abi.encodeWithSignature("ticks(int24)", tick));
                        int128 liquidityNet;
                        assembly {
                            liquidityNet := mload(add(deltaL, 64))
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

    /// @notice Algebra pools - linked list traversal via prevTick/nextTick, 9-return-value ticks()
    function queryAlgebraTicksSuperCompact2(address pool, uint256 iteration) public view returns (bytes memory) {
        int24 currTick;
        {
            (bool s, bytes memory res) = pool.staticcall(abi.encodeWithSignature("prevInitializedTick()"));
            if (s) {
                currTick = abi.decode(res, (int24));
            } else {
                (s, res) = pool.staticcall(abi.encodeWithSignature("globalState()"));
                if (s) {
                    assembly {
                        currTick := mload(add(res, 96))
                    }
                }
            }
        }

        int24 currTick2 = currTick;
        uint256 threshold = iteration / 2;
        // travel from left to right
        bytes memory tickInfo;

        while (currTick < MAX_TICK_PLUS_1 && iteration > threshold) {
            (, int128 liquidityNet,,, int24 prevTick, int24 nextTick,,,) = IAlgebraPool(pool).ticks(currTick);

            int256 data = int256(uint256(int256(currTick)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

            if (currTick == nextTick) {
                break;
            }
            currTick = nextTick;
            iteration--;
        }

        while (currTick2 > MIN_TICK_MINUS_1 && iteration > 0) {
            (, int128 liquidityNet,,, int24 prevTick, int24 nextTick,,,) = IAlgebraPool(pool).ticks(currTick2);

            int256 data = int256(uint256(int256(currTick2)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

            if (currTick2 == prevTick) {
                break;
            }
            currTick2 = prevTick;
            iteration--;
        }

        return tickInfo;
    }

    /// @notice Algebra Integral pools - linked list traversal, 6-return-value ticks()
    function queryAlgebraTicksSuperCompact2_v2(address pool, uint256 iteration) public view returns (bytes memory) {
        int24 currTick;
        // try to use prevTickGlobal() first, if not available, try to use globalState() instead
        {
            (bool s, bytes memory res) = pool.staticcall(abi.encodeWithSignature("prevTickGlobal()"));
            if (s) {
                currTick = abi.decode(res, (int24));
            } else {
                // prevTickGlobal() is not available, try to use globalState() instead
                // (, currTick, , , , ) = IAlgebraPoolIntegral(pool).globalState();
                (s, res) = pool.staticcall(abi.encodeWithSignature("globalState()"));
                if (s) {
                    assembly {
                        currTick := mload(add(res, 64))
                    }
                }
            }
        }

        int24 currTick2 = currTick;
        uint256 threshold = iteration / 2;
        // travel from left to right
        bytes memory tickInfo;

        while (currTick < MAX_TICK_PLUS_1 && iteration > threshold) {
            (, int128 liquidityNet, int24 prevTick, int24 nextTick, , ) = IAlgebraPoolIntegral(pool).ticks(currTick);

            int256 data = int256(uint256(int256(currTick)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

            if (currTick == nextTick) {
                break;
            }
            currTick = nextTick;
            iteration--;
        }

        // Skip initial tick (already processed above) by moving to prevTick first
        {
            (, , int24 prevTick, , , ) = IAlgebraPoolIntegral(pool).ticks(currTick2);
            // if the current tick is the same as the previous tick, means no more previous ticks to process, return the result
            if (currTick2 == prevTick) {
                return tickInfo;
            }
            currTick2 = prevTick;
        }

        while (currTick2 > MIN_TICK_MINUS_1 && iteration > 0) {
            (, int128 liquidityNet, int24 prevTick, int24 nextTick, , ) = IAlgebraPoolIntegral(pool).ticks(currTick2);

            int256 data = int256(uint256(int256(currTick2)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

            if (currTick2 == prevTick) {
                break;
            }
            currTick2 = prevTick;
            iteration--;
        }

        return tickInfo;
    }

    /// @notice Algebra pools - tick bitmap query, dynamic tickSpacing, full range scan
    function queryAlgebraTicksSuperCompact3_back(address pool, uint256 len) public view returns (bytes memory) {
        SuperVar memory tmp;
        tmp.tickSpacing = IAlgebraPool(pool).tickSpacing();

        {
            (, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("globalState()"));
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
            uint256 res = IAlgebraPoolV1_9(pool).tickTable(int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);
                        // (, int128 liquidityNet,,,,,,) = IAlgebraPoolV1_9(pool).ticks(int24(int256(tick)));
                        (, bytes memory deltaL) = pool.staticcall(abi.encodeWithSignature("ticks(int24)", tick));
                        int128 liquidityNet;
                        assembly {
                            liquidityNet := mload(add(deltaL, 64))
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
            uint256 res = IAlgebraPoolV1_9(pool).tickTable(int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;

                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);
                        // (, int128 liquidityNet,,,,,,) = IAlgebraPoolV1_9(pool).ticks(int24(int256(tick)));

                        (, bytes memory deltaL) = pool.staticcall(abi.encodeWithSignature("ticks(int24)", tick));
                        int128 liquidityNet;
                        assembly {
                            liquidityNet := mload(add(deltaL, 64))
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

    /// @notice Algebra pools - tick bitmap query, tickSpacing=1, bounded range (len*200 each direction)
    function queryAlgebraTicksSuperCompact3(address pool, uint256 len) public view returns (bytes memory) {
        SuperVar memory tmp;
        tmp.tickSpacing = 1;

        {
            (, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("globalState()"));
            int24 currTick;
            assembly {
                currTick := mload(add(slot0, 64))
            }
            tmp.currTick = currTick;
        }
        int24 step = int24(int256(len)) * 200;
        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position().
        // NOTE: Solidity division truncates toward zero, so negative ticks need floor adjustment.
        int24 compressed = tmp.currTick / tmp.tickSpacing;
        if (tmp.currTick < 0 && (tmp.currTick % tmp.tickSpacing != 0)) {
            compressed--;
        }
        tmp.right = compressed >> 8;
        tmp.leftMost = (tmp.currTick - step) / tmp.tickSpacing / int24(256) - 2;
        tmp.rightMost = (tmp.currTick + step) / tmp.tickSpacing / int24(256) + 1;

        tmp.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        tmp.initPoint2 = tmp.initPoint;

        bytes memory tickInfo;

        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res = IAlgebraPoolV1_9(pool).tickTable(int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);
                        // (, int128 liquidityNet,,,,,,) = IAlgebraPoolV1_9(pool).ticks(int24(int256(tick)));
                        (, bytes memory deltaL) = pool.staticcall(abi.encodeWithSignature("ticks(int24)", tick));
                        int128 liquidityNet;
                        assembly {
                            liquidityNet := mload(add(deltaL, 64))
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
            uint256 res = IAlgebraPoolV1_9(pool).tickTable(int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;

                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);
                        // (, int128 liquidityNet,,,,,,) = IAlgebraPoolV1_9(pool).ticks(int24(int256(tick)));

                        (, bytes memory deltaL) = pool.staticcall(abi.encodeWithSignature("ticks(int24)", tick));
                        int128 liquidityNet;
                        assembly {
                            liquidityNet := mload(add(deltaL, 64))
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
}
