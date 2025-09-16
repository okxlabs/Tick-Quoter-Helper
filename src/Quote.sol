// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

interface IZumiPool {
    function points(int24 tick) external view returns (uint256, int128, uint256, uint256, bool);

    function pointDelta() external view returns (int24);

    function orderOrEndpoint(int24 tick) external view returns (int24);

    function limitOrderData(int24 point)
        external
        view
        returns (
            uint128 sellingX,
            uint128 earnY,
            uint256 accEarnY,
            uint256 legacyAccEarnY,
            uint128 legacyEarnY,
            uint128 sellingY,
            uint128 earnX,
            uint128 legacyEarnX,
            uint256 accEarnX,
            uint256 legacyAccEarnX
        );

    function pointBitmap(int16 tick) external view returns (uint256);

    function factory() external view returns (address);
}

interface IHorizonPool {
    function tickDistance() external view returns (int24);

    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside,
            uint128 secondsPerLiquidityOutside
        );

    function initializedTicks(int24 tick) external view returns (int24 previous, int24 next);

    function getPoolState()
        external
        view
        returns (uint160 sqrtP, int24 currentTick, int24 nearestCurrentTick, bool locked);
}

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is IUniswapV3PoolImmutables, IUniswapV3PoolState {}

interface IAlgebraPool {
    function globalState()
        external
        view
        returns (
            uint160 price,
            int24 tick,
            int24 prevInitializedTick,
            uint16 fee,
            uint16 timepointIndex,
            uint8 communityFee,
            bool unlocked
        );

    function tickSpacing() external view returns (int24);

    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityTotal,
            int128 liquidityDelta,
            uint256 outerFeeGrowth0Token,
            uint256 outerFeeGrowth1Token,
            int24 prevTick,
            int24 nextTick,
            uint160 outerSecondsPerLiquidity,
            uint32 outerSecondsSpent,
            bool hasLimitOrders
        );

    function tickTable(int16 wordPosition) external view returns (uint256);
    function prevInitializedTick() external view returns (int24);
}

interface IAlgebraPoolV1_9 {
    function globalState()
        external
        view
        returns (
            uint160 price,
            int24 tick,
            int24 prevInitializedTick,
            uint16 fee,
            uint16 timepointIndex,
            uint8 communityFee,
            bool unlocked
        );

    function tickSpacing() external view returns (int24);
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityTotal,
            int128 liquidityDelta,
            uint256 outerFeeGrowth0Token,
            uint256 outerFeeGrowth1Token,
            int56 outerTickCumulative,
            uint160 outerSecondsPerLiquidity,
            uint32 outerSecondsSpent,
            bool initialized
        );
    function tickTable(int16 wordPosition) external view returns (uint256);
}

interface IStateView {
    type PoolId is bytes32;

    /// @notice Retrieves the tick bitmap of a pool at a specific tick.
    /// @dev Corresponds to pools[poolId].tickBitmap[tick]
    /// @param poolId The ID of the pool.
    /// @param tick The tick to retrieve the bitmap for.
    /// @return tickBitmap The bitmap of the tick.
    function getTickBitmap(PoolId poolId, int16 tick) external view returns (uint256 tickBitmap);

    /// @notice Retrieves the liquidity information of a pool at a specific tick.
    /// @dev Corresponds to pools[poolId].ticks[tick].liquidityGross and pools[poolId].ticks[tick].liquidityNet. A more gas efficient version of getTickInfo
    /// @param poolId The ID of the pool.
    /// @param tick The tick to retrieve liquidity for.
    /// @return liquidityGross The total position liquidity that references this tick
    /// @return liquidityNet The amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left)
    function getTickLiquidity(PoolId poolId, int24 tick)
        external
        view
        returns (uint128 liquidityGross, int128 liquidityNet);

    /// @notice Get Slot0 of the pool: sqrtPriceX96, tick, protocolFee, lpFee
    /// @dev Corresponds to pools[poolId].slot0
    /// @param poolId The ID of the pool.
    /// @return sqrtPriceX96 The square root of the price of the pool, in Q96 precision.
    /// @return tick The current tick of the pool.
    /// @return protocolFee The protocol fee of the pool.
    /// @return lpFee The swap fee of the pool.
    function getSlot0(PoolId poolId)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);
}

interface IPositionManager {
    type Currency is address;

    /// @notice Returns the key for identifying a pool
    struct PoolKey {
        /// @notice The lower currency of the pool, sorted numerically
        Currency currency0;
        /// @notice The higher currency of the pool, sorted numerically
        Currency currency1;
        /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
        uint24 fee;
        /// @notice Ticks that involve positions must be a multiple of tick spacing
        int24 tickSpacing;
        /// @notice The hooks of the pool
        IHooks hooks;
    }

    function poolKeys(bytes25 poolId) external view returns (PoolKey memory);
}

interface IHooks {}

interface ICLPoolManager {
    type PoolId is bytes32;

    /// @notice Get the tick info about a specific tick in the pool
    function getPoolTickInfo(PoolId id, int24 tick) external view returns (Tick.Info memory);

    /// @notice Get the tick bitmap info about a specific range (a word range) in the pool
    function getPoolBitmapInfo(PoolId id, int16 word) external view returns (uint256 tickBitmap);

    /// @notice Get Slot0 of the pool: sqrtPriceX96, tick, protocolFee, lpFee
    function getSlot0(PoolId id)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);
}

/// @notice Tick info library for Pancake Infinity
library Tick {
    struct Info {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }
}

/// @notice Pool parameters helper for extracting tickSpacing
library CLPoolParametersHelper {
    uint256 internal constant OFFSET_TICK_SPACING = 16;

    function getTickSpacing(bytes32 params) internal pure returns (int24 tickSpacing) {
        assembly {
            tickSpacing := and(shr(OFFSET_TICK_SPACING, params), 0xffffff)
        }
    }
}

interface IZoraCoin {
    type Currency is address;

    struct PoolKey {
        /// @notice The lower currency of the pool, sorted numerically
        Currency currency0;
        /// @notice The higher currency of the pool, sorted numerically
        Currency currency1;
        /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
        uint24 fee;
        /// @notice Ticks that involve positions must be a multiple of tick spacing
        int24 tickSpacing;
        /// @notice The hooks of the pool
        IHooks hooks;
    }

    function getPoolKey() external view returns (PoolKey memory);
}

interface IPoolManager {
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory);
}

/// @title DexNativeRouter
/// @notice Entrance of trading native token in web3-dex
contract QueryData {
    int24 internal constant MIN_TICK_MINUS_1 = -887_272 - 1;
    int24 internal constant MAX_TICK_PLUS_1 = 887_272 + 1;
    bytes32 public constant POOLS_SLOT = bytes32(uint256(6));
    address public immutable POOL_MANAGER;
    address public immutable STATE_VIEW;
    address public immutable POSITION_MANAGER;
    address public constant PANCAKE_INFINITY_CLPOOLMANAGER = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
    address public constant PANCAKE_INFINITY_POSITION_MANAGER = 0x55f4c8abA71A1e923edC303eb4fEfF14608cC226;

    constructor(address stateView, address positionManager, address poolManager) {
        STATE_VIEW = stateView;
        POSITION_MANAGER = positionManager;
        POOL_MANAGER = poolManager;
    }

    type Currency is address;
    /// @notice Returns the key for identifying a pool

    struct PoolKey {
        /// @notice The lower currency of the pool, sorted numerically
        Currency currency0;
        /// @notice The higher currency of the pool, sorted numerically
        Currency currency1;
        /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
        uint24 fee;
        /// @notice Ticks that involve positions must be a multiple of tick spacing
        int24 tickSpacing;
        /// @notice The hooks of the pool
        IHooks hooks;
    }

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
        tmp.right = tmp.currTick / int24(256);
        tmp.leftMost = -887_272 / int24(256) - 2;
        tmp.rightMost = 887_272 / int24(256) + 1;

        if (tmp.currTick < 0) {
            tmp.initPoint = (256 - (uint256(int256(-tmp.currTick)) % 256)) % 256;
        } else {
            tmp.initPoint = uint256(int256(tmp.currTick)) % 256;
        }
        tmp.initPoint2 = tmp.initPoint;

        if (tmp.currTick < 0) tmp.right--;

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

    function queryHorizonTicksSuperCompact(address pool, uint256 iteration) public view returns (bytes memory) {
        (,, int24 currTick,) = IHorizonPool(pool).getPoolState();
        int24 currTick2 = currTick;
        uint256 threshold = iteration / 2;

        // travel from left to right
        bytes memory tickInfo;

        while (currTick < MAX_TICK_PLUS_1 && iteration > threshold) {
            (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(currTick);

            int256 data = int256(uint256(int256(currTick)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));
            (, int24 nextTick) = IHorizonPool(pool).initializedTicks(currTick);
            if (currTick == nextTick) {
                break;
            }
            currTick = nextTick;
            iteration--;
        }

        while (currTick2 > MIN_TICK_MINUS_1 && iteration > 0) {
            (, int128 liquidityNet,,) = IHorizonPool(pool).ticks(currTick2);
            int256 data = int256(uint256(int256(currTick2)) << 128)
                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));
            (int24 prevTick,) = IHorizonPool(pool).initializedTicks(currTick2);
            if (prevTick == currTick2) {
                break;
            }
            currTick2 = prevTick;
            iteration--;
        }

        return tickInfo;
    }

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
        tmp.right = tmp.currTick / tmp.tickSpacing / int24(256);
        tmp.leftMost = (tmp.currTick - step) / tmp.tickSpacing / int24(256) - 2;
        tmp.rightMost = (tmp.currTick + step) / tmp.tickSpacing / int24(256) + 1;

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

    function queryUniv4TicksSuperCompact(bytes32 poolId, uint256 len) public view returns (bytes memory) {
        SuperVar memory tmp;
        IPositionManager.PoolKey memory poolkey = IPositionManager(POSITION_MANAGER).poolKeys(bytes25(poolId));
        tmp.tickSpacing = poolkey.tickSpacing;

        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) =
                IStateView(STATE_VIEW).getSlot0(statePoolId);
            tmp.currTick = tick;
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

    function queryPancakeInfinityTicksSuperCompact(bytes32 poolId, uint256 len) public view returns (bytes memory) {
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
            tmp.tickSpacing = CLPoolParametersHelper.getTickSpacing(parameters);
        }

        ICLPoolManager.PoolId clPoolId = ICLPoolManager.PoolId.wrap(poolId);

        {
            (, int24 tick,,) = ICLPoolManager(PANCAKE_INFINITY_CLPOOLMANAGER).getSlot0(clPoolId);
            tmp.currTick = tick;
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

    function queryZoraTicksSuperCompact(address coin, uint256 len) public view returns (bytes memory) {
        SuperVar memory tmp;
        IZoraCoin.PoolKey memory poolkey = IZoraCoin(coin).getPoolKey();
        tmp.tickSpacing = poolkey.tickSpacing;
        bytes32 poolId = toId(poolkey);
        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) =
                IStateView(STATE_VIEW).getSlot0(statePoolId);
            tmp.currTick = tick;
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

    // General function for all v4 pools
    function toId(IZoraCoin.PoolKey memory poolKey) public pure returns (bytes32 poolId) {
        assembly ("memory-safe") {
            // 0xa0 represents the total size of the poolKey struct (5 slots of 32 bytes)
            poolId := keccak256(poolKey, 0xa0)
        }
    }

    // Specifically for Zora
    function getPoolKeyOfZora(address coin) public view returns (IZoraCoin.PoolKey memory) {
        IZoraCoin.PoolKey memory poolKey = IZoraCoin(coin).getPoolKey();
        return poolKey;
    }

    // Specifically for Zora
    function getSlot0OfZora(address coin)
        public
        view
        returns (int256 liquidity, uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        IZoraCoin.PoolKey memory poolKey = IZoraCoin(coin).getPoolKey();
        bytes32 poolId = toId(poolKey);
        bytes32 slot = _getPoolStateSlot(poolId);
        bytes32[] memory slot0 = IPoolManager(POOL_MANAGER).extsload(slot, 4);
        bytes32 data = slot0[0];
        liquidity = int256(uint256(slot0[3]));

        //   24 bits  |24bits|24bits      |24 bits|160 bits
        // 0x000000   |000bb8|000000      |ffff75 |0000000000000000fe3aa841ba359daa0ea9eff7
        // ---------- | fee  |protocolfee | tick  | sqrtPriceX96
        assembly ("memory-safe") {
            // bottom 160 bits of data
            sqrtPriceX96 := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            // next 24 bits of data
            tick := signextend(2, shr(160, data))
            // next 24 bits of data
            protocolFee := and(shr(184, data), 0xFFFFFF)
            // last 24 bits of data
            lpFee := and(shr(208, data), 0xFFFFFF)
        }
    }

    function _getPoolStateSlot(bytes32 poolId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(poolId, POOLS_SLOT));
    }
}
