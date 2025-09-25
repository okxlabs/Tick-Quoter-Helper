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
        tmp.tickSpacing = IZumiPool(pool).pointDelta();
        {
            (, bytes memory slot0) = pool.staticcall(abi.encodeWithSignature("state()"));
            int24 currTick;
            assembly {
                currTick := mload(add(slot0, 64))
            }
            tmp.currTick = currTick;
        }

        tmp.right = tmp.currTick / tmp.tickSpacing / int24(256);
        tmp.leftMost = -887_272 / tmp.tickSpacing / int24(256) - 2;
        tmp.rightMost = 887_272 / tmp.tickSpacing / int24(256) + 1;

        if (tmp.currTick < 0) {
            tmp.initPoint = uint256(
                int256(tmp.currTick) / int256(tmp.tickSpacing)
                    - (int256(tmp.currTick) / int256(tmp.tickSpacing) / 256 - 1) * 256
            ) % 256;
        } else {
            tmp.initPoint = (uint256(int256(tmp.currTick)) / uint256(int256(tmp.tickSpacing))) % 256;
        }
        tmp.initPoint2 = tmp.initPoint;

        if (tmp.currTick < 0) tmp.right--;

        bytes memory tickInfo;
        bytes memory limitOrderInfo;

        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res = IZumiPool(pool).pointBitmap(int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int24 tick = int24(int256((256 * tmp.right + int256(i)) * tmp.tickSpacing));
                        int24 orderOrEndpoint = IZumiPool(pool).orderOrEndpoint(tick / tmp.tickSpacing);
                        if (orderOrEndpoint & 0x01 == 0x01) {
                            (, int128 liquidityNet,,,) = IZumiPool(pool).points(tick);
                            if (liquidityNet != 0) {
                                int256 data = int256(uint256(int256(tick)) << 128)
                                    + (
                                        int256(liquidityNet)
                                            & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
                                    );
                                tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

                                index++;
                            }
                        }
                        if (orderOrEndpoint & 0x02 == 0x02) {
                            (uint128 sellingX,,,,, uint128 sellingY,,,,) = IZumiPool(pool).limitOrderData(tick);
                            if (sellingX != 0 || sellingY != 0) {
                                bytes32 data =
                                    bytes32(abi.encodePacked(int32(tick), uint112(sellingX), uint112(sellingY)));
                                limitOrderInfo = bytes.concat(limitOrderInfo, data);

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
            uint256 res = IZumiPool(pool).pointBitmap(int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int24 tick = int24(int256((256 * tmp.left + int256(i)) * tmp.tickSpacing));

                        int24 orderOrEndpoint = IZumiPool(pool).orderOrEndpoint(tick / tmp.tickSpacing);
                        if (orderOrEndpoint & 0x01 == 0x01) {
                            (, int128 liquidityNet,,,) = IZumiPool(pool).points(tick);
                            if (liquidityNet != 0) {
                                int256 data = int256(uint256(int256(tick)) << 128)
                                    + (
                                        int256(liquidityNet)
                                            & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
                                    );
                                tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));

                                index++;
                            }
                        }
                        if (orderOrEndpoint & 0x02 == 0x02) {
                            (uint128 sellingX,,,,, uint128 sellingY,,,,) = IZumiPool(pool).limitOrderData(tick);
                            if (sellingX != 0 || sellingY != 0) {
                                bytes32 data =
                                    bytes32(abi.encodePacked(int32(tick), uint112(sellingX), uint112(sellingY)));
                                limitOrderInfo = bytes.concat(limitOrderInfo, data);

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
        return (tickInfo, limitOrderInfo);
    }
}
