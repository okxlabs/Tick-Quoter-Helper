// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// src/ekubo/interfaces/IExposedStorage.sol

// Exposes all the storage of a contract via view methods.
// Absent https://eips.ethereum.org/EIPS/eip-2330 this makes it easier to access specific pieces of state in the inheriting contract.
interface IExposedStorage {
    // Loads each slot after the function selector from the contract's storage and returns all of them.
    function sload() external view;
    // Loads each slot after the function selector from the contract's transient storage and returns all of them.
    function tload() external view;
}

// src/ekubo/interfaces/IFlashAccountant.sol

interface ILocker {
    function locked(uint256 id) external;
}

interface IForwardee {
    function forwarded(uint256 id, address originalLocker) external;
}

interface IPayer {
    function payCallback(uint256 id, address token) external;
}

interface IFlashAccountant {
    error NotLocked();
    error LockerOnly();
    error NoPaymentMade();
    error DebtsNotZeroed(uint256 id);
    // Thrown if the contract receives too much payment in the payment callback or from a direct native token transfer
    error PaymentOverflow();
    error PayReentrance();

    // Create a lock context
    // Any data passed after the function signature is passed through back to the caller after the locked function signature and data, with no additional encoding
    // In addition, any data returned from ILocker#locked is also returned from this function exactly as is, i.e. with no additional encoding or decoding
    // Reverts are also bubbled up
    function lock() external;

    // Forward the lock from the current locker to the given address
    // Any additional calldata is also passed through to the forwardee, with no additional encoding
    // In addition, any data returned from IForwardee#forwarded is also returned from this function exactly as is, i.e. with no additional encoding or decoding
    // Reverts are also bubbled up
    function forward(address to) external;

    // Pays the given amount of token, by calling the payCallback function on the caller to afford them the opportunity to make the payment.
    // This function, unlike lock and forward, does not return any of the returndata from the callback.
    // This function also cannot be re-entered like lock and forward.
    // Must be locked, as the contract accounts the payment against the current locker's debts.
    // Token must not be the NATIVE_TOKEN_ADDRESS, as the `balanceOf` calls will fail.
    // If you want to pay in the chain's native token, simply transfer it to this contract using a call.
    // The payer must implement payCallback in which they must transfer the token to Core.
    function pay(address token) external returns (uint128 payment);

    // Withdraws a token amount from the accountant to the given recipient.
    // The contract must be locked, as it tracks the withdrawn amount against the current locker's delta.
    function withdraw(address token, address recipient, uint128 amount) external;

    // This contract can receive ETH as a payment as well
    receive() external payable;
}

// src/ekubo/types/callPoints.sol

struct CallPoints {
    bool beforeInitializePool;
    bool afterInitializePool;
    bool beforeSwap;
    bool afterSwap;
    bool beforeUpdatePosition;
    bool afterUpdatePosition;
    bool beforeCollectFees;
    bool afterCollectFees;
}

using {eq_0, isValid_0, toUint8} for CallPoints global;

function eq_0(CallPoints memory a, CallPoints memory b) pure returns (bool) {
    return (
        a.beforeInitializePool == b.beforeInitializePool && a.afterInitializePool == b.afterInitializePool
            && a.beforeSwap == b.beforeSwap && a.afterSwap == b.afterSwap
            && a.beforeUpdatePosition == b.beforeUpdatePosition && a.afterUpdatePosition == b.afterUpdatePosition
            && a.beforeCollectFees == b.beforeCollectFees && a.afterCollectFees == b.afterCollectFees
    );
}

function isValid_0(CallPoints memory a) pure returns (bool) {
    return (
        a.beforeInitializePool || a.afterInitializePool || a.beforeSwap || a.afterSwap || a.beforeUpdatePosition
            || a.afterUpdatePosition || a.beforeCollectFees || a.afterCollectFees
    );
}

function toUint8(CallPoints memory callPoints) pure returns (uint8 b) {
    assembly ("memory-safe") {
        b :=
            add(
                add(
                    add(
                        add(
                            add(
                                add(
                                    add(mload(callPoints), mul(128, mload(add(callPoints, 32)))),
                                    mul(64, mload(add(callPoints, 64)))
                                ),
                                mul(32, mload(add(callPoints, 96)))
                            ),
                            mul(16, mload(add(callPoints, 128)))
                        ),
                        mul(8, mload(add(callPoints, 160)))
                    ),
                    mul(4, mload(add(callPoints, 192)))
                ),
                mul(2, mload(add(callPoints, 224)))
            )
    }
}

function addressToCallPoints(address a) pure returns (CallPoints memory result) {
    result = byteToCallPoints(uint8(uint160(a) >> 152));
}

function byteToCallPoints(uint8 b) pure returns (CallPoints memory result) {
    // note the order of bytes does not match the struct order of elements because we are matching the cairo implementation
    // which for legacy reasons has the fields in this order
    result = CallPoints({
        beforeInitializePool: (b & 1) != 0,
        afterInitializePool: (b & 128) != 0,
        beforeSwap: (b & 64) != 0,
        afterSwap: (b & 32) != 0,
        beforeUpdatePosition: (b & 16) != 0,
        afterUpdatePosition: (b & 8) != 0,
        beforeCollectFees: (b & 4) != 0,
        afterCollectFees: (b & 2) != 0
    });
}

function shouldCallBeforeInitializePool(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(152, a), 1)
    }
}

function shouldCallAfterInitializePool(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(159, a), 1)
    }
}

function shouldCallBeforeSwap(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(158, a), 1)
    }
}

function shouldCallAfterSwap(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(157, a), 1)
    }
}

function shouldCallBeforeUpdatePosition(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(156, a), 1)
    }
}

function shouldCallAfterUpdatePosition(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(155, a), 1)
    }
}

function shouldCallBeforeCollectFees(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(154, a), 1)
    }
}

function shouldCallAfterCollectFees(address a) pure returns (bool yes) {
    assembly ("memory-safe") {
        yes := and(shr(153, a), 1)
    }
}

// src/ekubo/math/constants.sol

int32 constant MIN_TICK = -88722835;
int32 constant MAX_TICK = 88722835;
uint32 constant MAX_TICK_MAGNITUDE = uint32(MAX_TICK);
uint32 constant MAX_TICK_SPACING = 698605;

uint32 constant FULL_RANGE_ONLY_TICK_SPACING = 0;

// We use this address to represent the native token within the protocol
address constant NATIVE_TOKEN_ADDRESS = address(0);

// src/ekubo/types/feesPerLiquidity.sol

// The total fees per liquidity for each token.
// Since these are always read together we put them in a struct, even though they cannot be packed.
struct FeesPerLiquidity {
    uint256 value0;
    uint256 value1;
}

using {sub} for FeesPerLiquidity global;

function sub(FeesPerLiquidity memory a, FeesPerLiquidity memory b) pure returns (FeesPerLiquidity memory result) {
    assembly ("memory-safe") {
        mstore(result, sub(mload(a), mload(b)))
        mstore(add(result, 32), sub(mload(add(a, 32)), mload(add(b, 32))))
    }
}

function feesPerLiquidityFromAmounts(uint128 amount0, uint128 amount1, uint128 liquidity)
    pure
    returns (FeesPerLiquidity memory result)
{
    assembly ("memory-safe") {
        mstore(result, div(shl(128, amount0), liquidity))
        mstore(add(result, 32), div(shl(128, amount1), liquidity))
    }
}

// src/ekubo/types/sqrtRatio.sol

// A dynamic fixed point number (a la floating point) that stores a shifting 94 bit view of the underlying fixed point value,
//  based on the most significant bits (mantissa)
// If the most significant 2 bits are 11, it represents a 64.30
// If the most significant 2 bits are 10, it represents a 32.62 number
// If the most significant 2 bits are 01, it represents a 0.94 number
// If the most significant 2 bits are 00, it represents a 0.126 number that is always less than 2**-32

type SqrtRatio is uint96;

uint96 constant MIN_SQRT_RATIO_RAW = 4611797791050542631;
SqrtRatio constant MIN_SQRT_RATIO = SqrtRatio.wrap(MIN_SQRT_RATIO_RAW);
uint96 constant MAX_SQRT_RATIO_RAW = 79227682466138141934206691491;
SqrtRatio constant MAX_SQRT_RATIO = SqrtRatio.wrap(MAX_SQRT_RATIO_RAW);

uint96 constant TWO_POW_95 = 0x800000000000000000000000;
uint96 constant TWO_POW_94 = 0x400000000000000000000000;
uint96 constant TWO_POW_62 = 0x4000000000000000;
uint96 constant TWO_POW_62_MINUS_ONE = 0x3fffffffffffffff;
uint96 constant BIT_MASK = 0xc00000000000000000000000; // TWO_POW_95 | TWO_POW_94

SqrtRatio constant ONE = SqrtRatio.wrap((TWO_POW_95) + (1 << 62));

using {
    toFixed,
    isValid_1,
    ge as >=,
    le as <=,
    lt as <,
    gt as >,
    eq_1 as ==,
    neq as !=,
    isZero,
    min,
    max
} for SqrtRatio global;

function isValid_1(SqrtRatio sqrtRatio) pure returns (bool r) {
    assembly ("memory-safe") {
        r :=
            and(
                // greater than or equal to TWO_POW_62, i.e. the whole number portion is nonzero
                gt(and(sqrtRatio, not(BIT_MASK)), TWO_POW_62_MINUS_ONE),
                // and between min/max sqrt ratio
                and(iszero(lt(sqrtRatio, MIN_SQRT_RATIO_RAW)), iszero(gt(sqrtRatio, MAX_SQRT_RATIO_RAW)))
            )
    }
}

error ValueOverflowsSqrtRatioContainer();

// If passing a value greater than this constant with roundUp = true, toSqrtRatio will overflow
// For roundUp = false, the constant is type(uint192).max
uint256 constant MAX_FIXED_VALUE_ROUND_UP =
    0x1000000000000000000000000000000000000000000000000 - 0x4000000000000000000000000;

// Converts a 64.128 value into the compact SqrtRatio representation
function toSqrtRatio(uint256 sqrtRatio, bool roundUp) pure returns (SqrtRatio r) {
    assembly ("memory-safe") {
        let addend := mul(roundUp, 0x3)

        // lt 2**96 after rounding up
        switch lt(sqrtRatio, sub(0x1000000000000000000000000, addend))
        case 1 { r := shr(2, add(sqrtRatio, addend)) }
        default {
            // 2**34 - 1
            addend := mul(roundUp, 0x3ffffffff)
            // lt 2**128 after rounding up
            switch lt(sqrtRatio, sub(0x100000000000000000000000000000000, addend))
            case 1 { r := or(TWO_POW_94, shr(34, add(sqrtRatio, addend))) }
            default {
                addend := mul(roundUp, 0x3ffffffffffffffff)
                // lt 2**160 after rounding up
                switch lt(sqrtRatio, sub(0x10000000000000000000000000000000000000000, addend))
                case 1 { r := or(TWO_POW_95, shr(66, add(sqrtRatio, addend))) }
                default {
                    // 2**98 - 1
                    addend := mul(roundUp, 0x3ffffffffffffffffffffffff)
                    switch lt(sqrtRatio, sub(0x1000000000000000000000000000000000000000000000000, addend))
                    case 1 { r := or(BIT_MASK, shr(98, add(sqrtRatio, addend))) }
                    default {
                        // cast sig "ValueOverflowsSqrtRatioContainer()"
                        mstore(0, shl(224, 0xa10459f4))
                        revert(0, 4)
                    }
                }
            }
        }
    }
}

// Returns the 64.128 representation of the given sqrt ratio
function toFixed(SqrtRatio sqrtRatio) pure returns (uint256 r) {
    assembly ("memory-safe") {
        r := shl(add(2, shr(89, and(sqrtRatio, BIT_MASK))), and(sqrtRatio, not(BIT_MASK)))
    }
}

// The below operators assume that the SqrtRatio is valid, i.e. SqrtRatio#isValid returns true

function lt(SqrtRatio a, SqrtRatio b) pure returns (bool r) {
    r = SqrtRatio.unwrap(a) < SqrtRatio.unwrap(b);
}

function gt(SqrtRatio a, SqrtRatio b) pure returns (bool r) {
    r = SqrtRatio.unwrap(a) > SqrtRatio.unwrap(b);
}

function le(SqrtRatio a, SqrtRatio b) pure returns (bool r) {
    r = SqrtRatio.unwrap(a) <= SqrtRatio.unwrap(b);
}

function ge(SqrtRatio a, SqrtRatio b) pure returns (bool r) {
    r = SqrtRatio.unwrap(a) >= SqrtRatio.unwrap(b);
}

function eq_1(SqrtRatio a, SqrtRatio b) pure returns (bool r) {
    r = SqrtRatio.unwrap(a) == SqrtRatio.unwrap(b);
}

function neq(SqrtRatio a, SqrtRatio b) pure returns (bool r) {
    r = SqrtRatio.unwrap(a) != SqrtRatio.unwrap(b);
}

function isZero(SqrtRatio a) pure returns (bool r) {
    assembly ("memory-safe") {
        r := iszero(a)
    }
}

function max(SqrtRatio a, SqrtRatio b) pure returns (SqrtRatio r) {
    assembly ("memory-safe") {
        r := xor(a, mul(xor(a, b), gt(b, a)))
    }
}

function min(SqrtRatio a, SqrtRatio b) pure returns (SqrtRatio r) {
    assembly ("memory-safe") {
        r := xor(a, mul(xor(a, b), lt(b, a)))
    }
}

// src/ekubo/libraries/ExposedStorageLib.sol

/// @dev This library includes some helper functions for calling IExposedStorage#sload and IExposedStorage#tload.
library ExposedStorageLib {
    function sload(IExposedStorage target, bytes32 slot) internal view returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0, shl(224, 0x380eb4e0))
            mstore(4, slot)

            if iszero(staticcall(gas(), target, 0, 36, 0, 32)) { revert(0, 0) }

            result := mload(0)
        }
    }

    function sload(IExposedStorage target, bytes32 slot0, bytes32 slot1, bytes32 slot2)
        internal
        view
        returns (bytes32 result0, bytes32 result1, bytes32 result2)
    {
        assembly ("memory-safe") {
            let o := mload(0x40)
            mstore(o, shl(224, 0x380eb4e0))
            mstore(add(o, 4), slot0)
            mstore(add(o, 36), slot1)
            mstore(add(o, 68), slot2)

            if iszero(staticcall(gas(), target, o, 100, o, 96)) { revert(0, 0) }

            result0 := mload(o)
            result1 := mload(add(o, 32))
            result2 := mload(add(o, 64))
        }
    }

    function tload(IExposedStorage target, bytes32 slot) internal view returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0, shl(224, 0xed832830))
            mstore(4, slot)

            if iszero(staticcall(gas(), target, 0, 36, 0, 32)) { revert(0, 0) }

            result := mload(0)
        }
    }
}

// src/ekubo/types/poolKey.sol

using {toPoolId, validatePoolKey, isFullRange, mustLoadFees, tickSpacing, fee, extension} for PoolKey global;

// address (20 bytes) | fee (8 bytes) | tickSpacing (4 bytes)
type Config is bytes32;

function tickSpacing(PoolKey memory pk) pure returns (uint32 r) {
    assembly ("memory-safe") {
        r := and(mload(add(64, pk)), 0xffffffff)
    }
}

function fee(PoolKey memory pk) pure returns (uint64 r) {
    assembly ("memory-safe") {
        r := and(mload(add(60, pk)), 0xffffffffffffffff)
    }
}

function extension(PoolKey memory pk) pure returns (address r) {
    assembly ("memory-safe") {
        r := and(mload(add(52, pk)), 0xffffffffffffffffffffffffffffffffffffffff)
    }
}

function mustLoadFees(PoolKey memory pk) pure returns (bool r) {
    assembly ("memory-safe") {
        // only if either of tick spacing and fee are nonzero
        // if _both_ are zero, then we know we do not need to load fees for swaps
        r := iszero(iszero(and(mload(add(64, pk)), 0xffffffffffffffffffffffff)))
    }
}

function isFullRange(PoolKey memory pk) pure returns (bool r) {
    r = pk.tickSpacing() == FULL_RANGE_ONLY_TICK_SPACING;
}

function toConfig(uint64 _fee, uint32 _tickSpacing, address _extension) pure returns (Config c) {
    assembly ("memory-safe") {
        c := add(add(shl(96, _extension), shl(32, _fee)), _tickSpacing)
    }
}

// Each pool has its own state associated with this key
struct PoolKey {
    address token0;
    address token1;
    Config config;
}

error TokensMustBeSorted();
error InvalidTickSpacing();

function validatePoolKey(PoolKey memory key) pure {
    if (key.token0 >= key.token1) revert TokensMustBeSorted();
    if (key.tickSpacing() > MAX_TICK_SPACING) {
        revert InvalidTickSpacing();
    }
}

function toPoolId(PoolKey memory key) pure returns (bytes32 result) {
    assembly ("memory-safe") {
        // it's already copied into memory
        result := keccak256(key, 96)
    }
}

// src/ekubo/types/positionKey.sol

using {toPositionId} for PositionKey global;
using {validateBounds} for Bounds global;

// Bounds are lower and upper prices for which a position is active
struct Bounds {
    int32 lower;
    int32 upper;
}

error BoundsOrder();
error MinMaxBounds();
error BoundsTickSpacing();
error FullRangeOnlyPool();

function validateBounds(Bounds memory bounds, uint32 tickSpacing) pure {
    if (tickSpacing == FULL_RANGE_ONLY_TICK_SPACING) {
        if (bounds.lower != MIN_TICK || bounds.upper != MAX_TICK) revert FullRangeOnlyPool();
    } else {
        if (bounds.lower >= bounds.upper) revert BoundsOrder();
        if (bounds.lower < MIN_TICK || bounds.upper > MAX_TICK) revert MinMaxBounds();
        int32 spacing = int32(tickSpacing);
        if (bounds.lower % spacing != 0 || bounds.upper % spacing != 0) revert BoundsTickSpacing();
    }
}

// A position is keyed by the pool and this position key
struct PositionKey {
    bytes32 salt;
    address owner;
    Bounds bounds;
}

function toPositionId(PositionKey memory key) pure returns (bytes32 result) {
    assembly ("memory-safe") {
        // salt and owner
        mstore(0, keccak256(key, 64))
        // bounds
        mstore(32, keccak256(mload(add(key, 64)), 64))

        result := keccak256(0, 64)
    }
}

// src/ekubo/interfaces/ICore.sol

struct UpdatePositionParameters {
    bytes32 salt;
    Bounds bounds;
    int128 liquidityDelta;
}

interface IExtension {
    function beforeInitializePool(address caller, PoolKey calldata key, int32 tick) external;
    function afterInitializePool(address caller, PoolKey calldata key, int32 tick, SqrtRatio sqrtRatio) external;

    function beforeUpdatePosition(address locker, PoolKey memory poolKey, UpdatePositionParameters memory params)
        external;
    function afterUpdatePosition(
        address locker,
        PoolKey memory poolKey,
        UpdatePositionParameters memory params,
        int128 delta0,
        int128 delta1
    ) external;

    function beforeSwap(
        address locker,
        PoolKey memory poolKey,
        int128 amount,
        bool isToken1,
        SqrtRatio sqrtRatioLimit,
        uint256 skipAhead
    ) external;
    function afterSwap(
        address locker,
        PoolKey memory poolKey,
        int128 amount,
        bool isToken1,
        SqrtRatio sqrtRatioLimit,
        uint256 skipAhead,
        int128 delta0,
        int128 delta1
    ) external;

    function beforeCollectFees(address locker, PoolKey memory poolKey, bytes32 salt, Bounds memory bounds) external;
    function afterCollectFees(
        address locker,
        PoolKey memory poolKey,
        bytes32 salt,
        Bounds memory bounds,
        uint128 amount0,
        uint128 amount1
    ) external;
}

interface ICore is IFlashAccountant, IExposedStorage {
    event ProtocolFeesWithdrawn(address recipient, address token, uint256 amount);
    event ExtensionRegistered(address extension);
    event PoolInitialized(bytes32 poolId, PoolKey poolKey, int32 tick, SqrtRatio sqrtRatio);
    event PositionFeesCollected(bytes32 poolId, PositionKey positionKey, uint128 amount0, uint128 amount1);
    event FeesAccumulated(bytes32 poolId, uint128 amount0, uint128 amount1);
    event PositionUpdated(
        address locker, bytes32 poolId, UpdatePositionParameters params, int128 delta0, int128 delta1
    );

    // This error is thrown by swaps and deposits when this particular deployment of the contract is expired.
    error FailedRegisterInvalidCallPoints();
    error ExtensionAlreadyRegistered();
    error InsufficientSavedBalance();
    error PoolAlreadyInitialized();
    error ExtensionNotRegistered();
    error PoolNotInitialized();
    error MustCollectFeesBeforeWithdrawingAllLiquidity();
    error SqrtRatioLimitOutOfRange();
    error InvalidSqrtRatioLimit();
    error SavedBalanceTokensNotSorted();

    // Allows the owner of the contract to withdraw the protocol withdrawal fees collected
    // To withdraw the native token protocol fees, call with token = NATIVE_TOKEN_ADDRESS
    function withdrawProtocolFees(address recipient, address token, uint256 amount) external;

    // Extensions must call this function to become registered. The call points are validated against the caller address
    function registerExtension(CallPoints memory expectedCallPoints) external;

    // Sets the initial price for a new pool in terms of tick.
    function initializePool(PoolKey memory poolKey, int32 tick) external returns (SqrtRatio sqrtRatio);

    function prevInitializedTick(bytes32 poolId, int32 fromTick, uint32 tickSpacing, uint256 skipAhead)
        external
        view
        returns (int32 tick, bool isInitialized);

    function nextInitializedTick(bytes32 poolId, int32 fromTick, uint32 tickSpacing, uint256 skipAhead)
        external
        view
        returns (int32 tick, bool isInitialized);

    // Loads 2 tokens from the saved balances of the caller as payment in the current context.
    function load(address token0, address token1, bytes32 salt, uint128 amount0, uint128 amount1) external;

    // Saves an amount of 2 tokens to be used later, in a single slot.
    function save(address owner, address token0, address token1, bytes32 salt, uint128 amount0, uint128 amount1)
        external
        payable;

    // Returns the pool fees per liquidity inside the given bounds.
    function getPoolFeesPerLiquidityInside(PoolKey memory poolKey, Bounds memory bounds)
        external
        view
        returns (FeesPerLiquidity memory);

    // Accumulates tokens to fees of a pool. Only callable by the extension of the specified pool
    // key, i.e. the current locker _must_ be the extension.
    // The extension must call this function within a lock callback.
    function accumulateAsFees(PoolKey memory poolKey, uint128 amount0, uint128 amount1) external payable;

    function updatePosition(PoolKey memory poolKey, UpdatePositionParameters memory params)
        external
        payable
        returns (int128 delta0, int128 delta1);

    function collectFees(PoolKey memory poolKey, bytes32 salt, Bounds memory bounds)
        external
        returns (uint128 amount0, uint128 amount1);

    function swap_611415377(
        PoolKey memory poolKey,
        int128 amount,
        bool isToken1,
        SqrtRatio sqrtRatioLimit,
        uint256 skipAhead
    ) external payable returns (int128 delta0, int128 delta1);
}

// src/ekubo/libraries/CoreLib.sol

// Common storage getters we need for external contracts are defined here instead of in the core contract
library CoreLib {
    using ExposedStorageLib for *;

    function poolState(ICore core, bytes32 poolId)
        internal
        view
        returns (SqrtRatio sqrtRatio, int32 tick, uint128 liquidity)
    {
        bytes32 key;
        assembly ("memory-safe") {
            mstore(0, poolId)
            mstore(32, 2)
            key := keccak256(0, 64)
        }

        bytes32 p = core.sload(key);

        assembly ("memory-safe") {
            sqrtRatio := and(p, 0xffffffffffffffffffffffff)
            tick := and(shr(96, p), 0xffffffff)
            liquidity := shr(128, p)
        }
    }

    function poolTicks(ICore core, bytes32 poolId, int32 tick)
        internal
        view
        returns (int128 liquidityDelta, uint128 liquidityNet)
    {
        bytes32 key;
        assembly ("memory-safe") {
            mstore(0, poolId)
            mstore(32, 5)
            let b := keccak256(0, 64)
            mstore(0, tick)
            mstore(32, b)
            key := keccak256(0, 64)
        }

        bytes32 data = core.sload(key);

        // takes only least significant 128 bits
        liquidityDelta = int128(uint128(uint256(data)));
        // takes only most significant 128 bits
        liquidityNet = uint128(bytes16(data));
    }
}

// src/ekubo/QueryEkubo.sol

contract QueryEkubo {
    using CoreLib for ICore;

    ICore core;

    int32 constant MIN_TICK = -88722835;
    int32 constant MAX_TICK = 88722835;

    constructor(address _core) {
        core = ICore(payable(_core));
    }

    function poolState(
        bytes32 poolId
    ) public view returns (SqrtRatio sqrtRatio, int32 tick, uint128 liquidity) {
        return core.poolState(poolId);
    }

    function poolTicks(
        bytes32 poolId,
        int32 tick
    ) public view returns (int128 liquidityDelta, uint128 liquidityNet) {
        return core.poolTicks(poolId, tick);
    }

    function poolTickSpacing(PoolKey memory pk) external view returns (uint32) {
        return pk.tickSpacing();
    }

    function queryEkuboTicksSuperCompactByTokens(
        address token0,
        address token1,
        bytes32 config
    ) public view returns (bytes memory) {
        PoolKey memory poolkey = PoolKey({
            token0: token0,
            token1: token1,
            config: Config.wrap(config)
        });
        return queryEkuboTicksSuperCompactByPoolKey(poolkey);
    }

    function queryEkuboTicksSuperCompactByPoolKey(
        PoolKey memory poolKey
    ) public view returns (bytes memory) {
        int32 tickSpacing = int32(poolKey.tickSpacing());
        require(tickSpacing > 0, "Invalid tickSpacing");
        bytes32 poolId = poolKey.toPoolId();
        int32 leftMost = (MIN_TICK / tickSpacing) * tickSpacing;
        int32 rightMost = (MAX_TICK / tickSpacing) * tickSpacing;
        bytes memory tickInfo;
        int32 index = leftMost;
        bool isInitialized;
        while (true) {
            (index, isInitialized) = core.nextInitializedTick(
                poolId,
                index,
                uint32(tickSpacing),
                0
            );
            if (index >= rightMost) {
                break;
            }
            if (isInitialized) {
                (int128 liquidityDelta, uint128 liquidityNet) = poolTicks(
                    poolId,
                    index
                );

                int256 data = int256(uint256(int256(index)) << 128) +
                    (int256(liquidityDelta) &
                        0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                tickInfo = bytes.concat(tickInfo, bytes32(uint256(data)));
            }
        }

        return tickInfo;
    }
}
