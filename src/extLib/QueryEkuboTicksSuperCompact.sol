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
import "../interface/IEkuboCore.sol";
import "forge-std/console.sol";
// ╭---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------╮
// | Name                            | Type                                                          | Slot | Offset | Bytes | Contract          |
// +=============================================================================================================================================+
// | isExtensionRegistered           | mapping(address => bool)                                      | 0    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | protocolFeesCollected           | mapping(address => uint256)                                   | 1    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | poolState                       | mapping(bytes32 => struct Core.PoolState)                     | 2    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | poolFeesPerLiquidity            | mapping(bytes32 => struct FeesPerLiquidity)                   | 3    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | poolPositions                   | mapping(bytes32 => mapping(bytes32 => struct Position))       | 4    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | poolTicks                       | mapping(bytes32 => mapping(int32 => struct Core.TickInfo))    | 5    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | poolTickFeesPerLiquidityOutside | mapping(bytes32 => mapping(int32 => struct FeesPerLiquidity)) | 6    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | poolInitializedTickBitmaps      | mapping(bytes32 => mapping(uint256 => Bitmap))                | 7    | 0      | 32    | src/Core.sol:Core |
// |---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------|
// | savedBalances                   | mapping(bytes32 => uint256)                                   | 8    | 0      | 32    | src/Core.sol:Core |
// ╰---------------------------------+---------------------------------------------------------------+------+--------+-------+-------------------╯

library QueryEkuboTicksSuperCompact {
    // address (20 bytes) | fee (8 bytes) | tickSpacing (4 bytes)

    struct PoolKey {
        address token0;
        address token1;
        bytes32 config;
    }

    int24 internal constant MIN_TICK_MINUS_1 = -887_272 - 1;
    int24 internal constant MAX_TICK_PLUS_1 = 887_272 + 1;
    bytes32 public constant POOLS_SLOT = bytes32(uint256(6));

    address public constant PANCAKE_INFINITY_CLPOOLMANAGER = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
    address public constant PANCAKE_INFINITY_POSITION_MANAGER = 0x55f4c8abA71A1e923edC303eb4fEfF14608cC226;
    uint256 internal constant OFFSET_TICK_SPACING = 16;
    address internal constant EKUBO_CORE_ETH = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;
    uint256 constant POOL_STATE_SLOT = 2;
    uint256 constant POOL_TICKS_SLOT = 5;
    uint256 constant POOL_TICK_BITMAPS_SLOT = 7;

    uint256 internal constant TICK_MASK = 0x000000000000000000000000ffffffff00000000000000000000000000000000;
    uint256 internal constant CURR_LIQUIDITY_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;
    uint256 internal constant LIQUIDITY_DELTA_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;

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

    function _getTickSpacing(PoolKey memory pk) internal pure returns (int24 r) {
        assembly ("memory-safe") {
            r := and(mload(add(64, pk)), 0xffffffff)
        }
    }

    function fee(PoolKey memory pk) internal pure returns (uint64 r) {
        assembly ("memory-safe") {
            r := and(mload(add(60, pk)), 0xffffffffffffffff)
        }
    }

    function extension(PoolKey memory pk) internal pure returns (address r) {
        assembly ("memory-safe") {
            r := and(mload(add(52, pk)), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    function toPoolId(PoolKey memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // it's already copied into memory
            result := keccak256(key, 96)
        }
    }

    function tickToBitmapWordAndIndex(int32 tick, int24 tickSpacing)
        internal
        pure
        returns (uint256 word, uint256 index)
    {
        assembly ("memory-safe") {
            let rawIndex := add(sub(sdiv(tick, tickSpacing), slt(smod(tick, tickSpacing), 0)), 89421695)
            word := div(rawIndex, 256)
            index := mod(rawIndex, 256)
        }
    }

    function bitmapWordAndIndexToTick(uint256 word, uint256 index, uint32 tickSpacing)
        internal
        pure
        returns (int32 tick)
    {
        assembly ("memory-safe") {
            let rawIndex := add(mul(word, 256), index)
            tick := mul(sub(rawIndex, 89421695), tickSpacing)
        }
    }

    function _toPoolId(PoolKey memory key) internal pure returns (bytes32) {
        return toPoolId(key);
    }

    function _getCurrentLiquidity(PoolKey memory poolKey) internal view returns (uint256) {
        bytes32 poolId = toPoolId(poolKey);
        bytes32 slot = keccak256(abi.encode(poolId, POOL_STATE_SLOT));
        (, bytes memory res) = EKUBO_CORE_ETH.staticcall(abi.encodeWithSelector(IEkuboCore.sload.selector, slot));
        uint256 data = abi.decode(res, (uint256));
        assembly {
            data := shr(128, and(data, CURR_LIQUIDITY_MASK))
        }
        return data;
    }

    function _getCurrentTick(PoolKey memory poolKey) internal view returns (int24) {
        bytes32 poolId = toPoolId(poolKey);
        // Calculate storage slot for poolState mapping: keccak256(abi.encode(poolId, POOL_STATE_SLOT))
        bytes32 slot = keccak256(abi.encode(poolId, POOL_STATE_SLOT));

        // Read PoolState from storage
        // PoolState struct layout:
        // - SqrtRatio sqrtRatio (32 bytes)
        // - int32 tick (4 bytes)
        // - uint128 liquidity (16 bytes)

        (, bytes memory res) = EKUBO_CORE_ETH.staticcall(abi.encodeWithSelector(IEkuboCore.sload.selector, slot));
        uint256 p = abi.decode(res, (uint256));
        int24 tick;
        assembly ("memory-safe") {
            let sqrtRatio := and(p, 0xffffffffffffffffffffffff)
            tick := and(shr(96, p), 0xffffffff)
            let liquidity := shr(128, p)
        }
        console.log("tick: %d", tick);
        return tick;
    }

    function _getTickBitMap(PoolKey memory poolKey, int256 tick) internal view returns (uint256) {
        bytes32 poolId = toPoolId(poolKey);

        int24 tickSpacing = _getTickSpacing(poolKey);
        (uint256 word,) = tickToBitmapWordAndIndex(int32(tick), tickSpacing);
        bytes32 slot = keccak256(abi.encode(poolId, POOL_TICK_BITMAPS_SLOT));
        slot = keccak256(abi.encode(word, slot));
        (, bytes memory res) = EKUBO_CORE_ETH.staticcall(abi.encodeWithSelector(IEkuboCore.sload.selector, slot));
        uint256 data = abi.decode(res, (uint256));
        return data;
    }

    function _getLiquidityDelta(PoolKey memory poolKey, int256 tick) internal view returns (int128) {
        bytes32 poolId = toPoolId(poolKey);

        bytes32 slot = keccak256(abi.encode(poolId, POOL_TICKS_SLOT));
        slot = keccak256(abi.encode(tick, slot));
        (, bytes memory res) = EKUBO_CORE_ETH.staticcall(abi.encodeWithSelector(IEkuboCore.sload.selector, slot));
        bytes32 data = abi.decode(res, (bytes32));
        // takes only least significant 128 bits
        int128 liquidityDelta = int128(uint128(uint256(data)));
        // takes only most significant 128 bits
        uint128 liquidityNet = uint128(bytes16(data));
        return liquidityDelta;
    }

    function _toRawIndex(int256 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 rawIndex;
        assembly ("memory-safe") {
            rawIndex := add(sub(sdiv(tick, tickSpacing), slt(smod(tick, tickSpacing), 0)), 89421695)
        }
        return rawIndex;
    }
    function _toTick(int256 rawIndex, int24 tickSpacing) internal pure returns (int24) {
        int24 tick;
        assembly ("memory-safe") {
            tick := mul(sub(rawIndex, 89421695), tickSpacing)
        }
        return tick;
    }

    function queryEkuboTicksSuperCompact(PoolKey memory poolKey, uint256 len) public view returns (bytes memory) {
        SuperVar memory tmp;

        tmp.tickSpacing = _getTickSpacing(poolKey);
        console.log("tickSpacing: %d", tmp.tickSpacing);
        tmp.currTick = _toRawIndex(_getCurrentTick(poolKey), tmp.tickSpacing);
        console.log("currTick: %d", tmp.currTick);
        console.logBytes32(toPoolId(poolKey));
        console.log("rawIndex: %d", _toRawIndex(_getCurrentTick(poolKey), tmp.tickSpacing));
        console.log("tick: %d", _toTick(_toRawIndex(_getCurrentTick(poolKey), tmp.tickSpacing), tmp.tickSpacing));

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

        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res = _getTickBitMap(poolKey, tmp.right);
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);
                        tick = _toTick(tick, tmp.tickSpacing);
                        console.log("tickR: %d", tick);
                        // (, int128 LiquidityDelta,,,,,,) = IUniswapV3Pool(pool).ticks(int24(int256(tick)));
                        int128 LiquidityDelta = _getLiquidityDelta(poolKey, tick);

                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(LiquidityDelta) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
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
            uint256 res = _getTickBitMap(poolKey, tmp.left);
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);
                        tick = _toTick(tick, tmp.tickSpacing);
                        console.log("tickL: %d", tick);
                        // (, int128 LiquidityDelta,,,,,,) = IUniswapV3Pool(pool).ticks(int24(int256(tick)));
                        // fix-bug: to make consistent with solidlyV3 and ramsesV2
                        int128 LiquidityDelta = _getLiquidityDelta(poolKey, tick);
                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(LiquidityDelta) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
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
