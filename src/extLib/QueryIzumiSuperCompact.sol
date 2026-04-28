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

library QueryIzumiSuperCompact {
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

    function queryIzumiSuperCompact(address pool, uint256 len) public view returns (bytes memory, bytes memory) {
        SuperVar memory tmp;
        {
            (bool pd, bytes memory pdd) = pool.staticcall(abi.encodeWithSelector(IZumiPool.pointDelta.selector));
            require(pd, "err_quoter_izumi_pointDelta_failed");
            tmp.tickSpacing = abi.decode(pdd, (int24));
            require(tmp.tickSpacing != 0, "err_quoter_izumi_tickSpacing_zero");
        }
        {
            (bool success, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("state()"));
            require(success, "err_quoter_izumi_state_failed");
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
        bytes memory limitOrderInfo = new bytes(len * 32);
        uint256 tickCount = 0;
        uint256 orderCount = 0;

        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res;
            try IZumiPool(pool).pointBitmap(int16(tmp.right)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_izumi_pointBitmap_failed");
            }
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int24 tick = int24(int256((256 * tmp.right + int256(i)) * tmp.tickSpacing));
                        int24 orderOrEndpoint;
                        try IZumiPool(pool).orderOrEndpoint(tick / tmp.tickSpacing) returns (int24 _oe) {
                            orderOrEndpoint = _oe;
                        } catch {
                            revert("err_quoter_izumi_orderOrEndpoint_failed");
                        }
                        if (orderOrEndpoint & 0x01 == 0x01) {
                            int128 liquidityNet;
                            try IZumiPool(pool).points(tick) returns (uint256, int128 _liquidityNet, uint256, uint256, bool) {
                                liquidityNet = _liquidityNet;
                            } catch {
                                revert("err_quoter_izumi_points_failed");
                            }
                            if (liquidityNet != 0) {
                                int256 data = int256(uint256(int256(tick)) << 128)
                                    + (
                                        int256(liquidityNet)
                                            & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
                                    );
                                // Write packed bytes32 directly into the pre-allocated buffer.
                                assembly {
                                    mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                                }
                                tickCount++;
                                index++;
                            }
                        }
                        if (orderOrEndpoint & 0x02 == 0x02) {
                            uint128 sellingX;
                            uint128 sellingY;
                            try IZumiPool(pool).limitOrderData(tick) returns (uint128 _sellingX, uint128, uint256, uint256, uint128, uint128 _sellingY, uint128, uint128, uint256, uint256) {
                                sellingX = _sellingX;
                                sellingY = _sellingY;
                            } catch {
                                revert("err_quoter_izumi_limitOrderData_failed");
                            }
                            if (sellingX != 0 || sellingY != 0) {
                                bytes32 data =
                                    bytes32(abi.encodePacked(int32(tick), uint112(sellingX), uint112(sellingY)));
                                assembly {
                                    mstore(add(limitOrderInfo, add(32, mul(orderCount, 32))), data)
                                }
                                orderCount++;
                                index++;
                            }
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
            try IZumiPool(pool).pointBitmap(int16(tmp.left)) returns (uint256 _res) {
                res = _res;
            } catch {
                revert("err_quoter_izumi_pointBitmap_failed");
            }
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int24 tick = int24(int256((256 * tmp.left + int256(i)) * tmp.tickSpacing));

                        int24 orderOrEndpoint;
                        try IZumiPool(pool).orderOrEndpoint(tick / tmp.tickSpacing) returns (int24 _oe) {
                            orderOrEndpoint = _oe;
                        } catch {
                            revert("err_quoter_izumi_orderOrEndpoint_failed");
                        }
                        if (orderOrEndpoint & 0x01 == 0x01) {
                            int128 liquidityNet;
                            try IZumiPool(pool).points(tick) returns (uint256, int128 _liquidityNet, uint256, uint256, bool) {
                                liquidityNet = _liquidityNet;
                            } catch {
                                revert("err_quoter_izumi_points_failed");
                            }
                            if (liquidityNet != 0) {
                                int256 data = int256(uint256(int256(tick)) << 128)
                                    + (
                                        int256(liquidityNet)
                                            & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
                                    );
                                assembly {
                                    mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                                }
                                tickCount++;
                                index++;
                            }
                        }
                        if (orderOrEndpoint & 0x02 == 0x02) {
                            uint128 sellingX;
                            uint128 sellingY;
                            try IZumiPool(pool).limitOrderData(tick) returns (uint128 _sellingX, uint128, uint256, uint256, uint128, uint128 _sellingY, uint128, uint128, uint256, uint256) {
                                sellingX = _sellingX;
                                sellingY = _sellingY;
                            } catch {
                                revert("err_quoter_izumi_limitOrderData_failed");
                            }
                            if (sellingX != 0 || sellingY != 0) {
                                bytes32 data =
                                    bytes32(abi.encodePacked(int32(tick), uint112(sellingX), uint112(sellingY)));
                                assembly {
                                    mstore(add(limitOrderInfo, add(32, mul(orderCount, 32))), data)
                                }
                                orderCount++;
                                index++;
                            }
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
        // Trim arrays to actual lengths (no empty content returned).
        assembly {
            mstore(tickInfo, mul(tickCount, 32))
            mstore(limitOrderInfo, mul(orderCount, 32))
        }
        return (tickInfo, limitOrderInfo);
    }
}
