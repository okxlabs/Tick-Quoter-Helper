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

library QueryHorizonTicksSuperCompact {
    int24 internal constant MIN_TICK_MINUS_1 = -887_272 - 1;
    int24 internal constant MAX_TICK_PLUS_1 = 887_272 + 1;
    bytes32 public constant POOLS_SLOT = bytes32(uint256(6));
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

    function queryHorizonTicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        (,, int24 currTick,) = IHorizonPool(pool).getPoolState();
        int24 currTick2 = currTick;
        uint256 threshold = len / 2;

        // travel from left to right
        bytes memory tickInfo;

        while (currTick < MAX_TICK_PLUS_1 && len > threshold) {
            (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(currTick);

            int256 data = int256(uint256(int256(currTick)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));
            (, int24 nextTick) = IHorizonPool(pool).initializedTicks(currTick);
            if (currTick == nextTick) {
                break;
            }
            currTick = nextTick;
            len--;
        }

        while (currTick2 > MIN_TICK_MINUS_1 && len > 0) {
            (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(currTick2);
            int256 data = int256(uint256(int256(currTick2)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));
            (int24 prevTick,) = IHorizonPool(pool).initializedTicks(currTick2);
            if (prevTick == currTick2) {
                break;
            }
            currTick2 = prevTick;
            len--;
        }

        return tickInfo;
    }
}
