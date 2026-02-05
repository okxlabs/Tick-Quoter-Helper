// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interface/IAlgebraPool.sol";
import "./interface/ICLPoolManager.sol";
import "./interface/IHooks.sol";
import "./interface/IHorizonPool.sol";
import "./interface/IPoolManager.sol";
import "./interface/IPositionManager.sol";
import "./interface/IStateView.sol";
import "./interface/IUniswapV3Pool.sol";
import "./interface/IZora.sol";
import "./interface/IZumiPool.sol";

import "./extLib/QueryUniv3TicksSuperCompact.sol";
import "./extLib/QueryAlgebraTicksSuperCompact.sol";
import "./extLib/QueryHorizonTicksSuperCompact.sol";
import "./extLib/QueryIzumiSuperCompact.sol";
import "./extLib/QueryUniv4TicksSuperCompact.sol";
import "./extLib/QueryZoraTicksSuperCompact.sol";
import "./extLib/QueryPancakeInfinityLBReserveSuperCompact.sol";
import "./extLib/QueryFluid.sol";
import "./extLib/QueryFluidLite.sol";
import "./extLib/QueryFluidDexV2D3D4.sol";
import "./extLib/QueryEkubo.sol";

contract QueryData is OwnableUpgradeable {
    // Core contract addresses
    address public constant POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address public constant STATE_VIEW = 0xA3c0c9b65baD0b08107Aa264b0f3dB444b867A71;
    address public constant POSITION_MANAGER = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    // FluidLite contract addresses
    address public constant FLUID_LITE_DEX = 0x0000000000000000000000000000000000000000;
    address public constant FLUID_LITE_DEPLOYER_CONTRACT = 0x0000000000000000000000000000000000000000;
    // FluidDexV2 contract addresses
    address public constant FLUID_LIQUIDITY = 0x0000000000000000000000000000000000000000; // For both FluidDexV2 D3 and D4
    address public constant FLUID_DEX_V2 = 0x0000000000000000000000000000000000000000; // For both FluidDexV2 D3 and D4
    // Ekubo contract addresses
    address public constant EKUBO_CORE = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;

    function initialize() public initializer {
        __Ownable_init();
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
        return QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompact(pool, len);
    }

    function queryUniv3TicksSuperCompactOneSide(address pool, bool isLeft) public view returns (bytes memory) {
        return QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompactOneSide(pool, isLeft);
    }

    function queryUniv3TicksSuperCompactAuto(address pool) public view returns (bytes memory) {
        return QueryUniv3TicksSuperCompact.queryUniv3TicksSuperCompactAuto(pool);
    }

    function queryAlgebraTicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact(pool, len);
    }

    function queryAlgebraTicksSuperCompact3_back(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact3_back(pool, len);
    }

    function queryHorizonTicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        return QueryHorizonTicksSuperCompact.queryHorizonTicksSuperCompact(pool, len);
    }

    function queryHorizonTicksSuperCompactOneSide(address pool, bool isLeft) public view returns (bytes memory) {
        return QueryHorizonTicksSuperCompact.queryHorizonTicksSuperCompactOneSide(pool, isLeft);
    }

    function queryHorizonTicksSuperCompactAuto(address pool) public view returns (bytes memory) {
        return QueryHorizonTicksSuperCompact.queryHorizonTicksSuperCompactAuto(pool);
    }

    function queryAlgebraTicksSuperCompact2(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact2(pool, len);
    }

    function queryAlgebraTicksSuperCompact2_v2(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact2_v2(pool, len);
    }

    function queryIzumiSuperCompact(address pool, uint256 len) public view returns (bytes memory, bytes memory) {
        return QueryIzumiSuperCompact.queryIzumiSuperCompact(pool, len);
    }

    function queryAlgebraTicksSuperCompact3(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact3(pool, len);
    }

    function queryUniv4TicksSuperCompact(bytes32 poolId, uint256 len) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompact(
            poolId, len, STATE_VIEW, POSITION_MANAGER
        );
    }

    function queryUniv4TicksSuperCompactOneSide(bytes32 poolId, bool isLeft) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactOneSide(
            poolId, STATE_VIEW, POSITION_MANAGER, isLeft
        );
    }

    function queryUniv4TicksSuperCompactAuto(bytes32 poolId) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactAuto(
            poolId, STATE_VIEW, POSITION_MANAGER
        );
    }

    /*
    * @notice Query the ticks of a Uniswap V4 pool for no position manager
    * @param poolId The ID of the pool
    * @param len The length of the ticks
    * @param STATE_VIEW The address of the state view
    * @param poolkey The pool key
    * @return The ticks
    */
    function queryUniv4TicksSuperCompactForNoPositionManager(bytes32 poolId, uint256 len, IPositionManager.PoolKey calldata poolkey) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactForNoPositionManager(
            poolId, len, STATE_VIEW, poolkey
        );
    }

    function queryUniv4TicksSuperCompactForNoPositionManagerOneSide(bytes32 poolId, IPositionManager.PoolKey calldata poolkey, bool isLeft) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactForNoPositionManagerOneSide(
            poolId, STATE_VIEW, poolkey, isLeft
        );
    }

    function queryUniv4TicksSuperCompactForNoPositionManagerAuto(bytes32 poolId, IPositionManager.PoolKey calldata poolkey) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryUniv4TicksSuperCompactForNoPositionManagerAuto(
            poolId, STATE_VIEW, poolkey
        );
    }

    function queryPancakeInfinityTicksSuperCompact(bytes32 poolId, uint256 len) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompact(
            poolId, len
        );
    }

    function queryPancakeInfinityTicksSuperCompactOneSide(bytes32 poolId, bool isLeft) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompactOneSide(poolId, isLeft);
    }

    function queryPancakeInfinityTicksSuperCompactAuto(bytes32 poolId) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompactAuto(poolId);
    }

    function queryPancakeInfinityLBReserveSuperCompact(bytes32 poolId) public view returns (uint256 totalReserveX, uint256 totalReserveY) {
        return QueryPancakeInfinityLBReserveSuperCompact.queryPancakeInfinityLBReserve(
            poolId
        );
    }

    function queryZoraTicksSuperCompact(address coin, uint256 len) public view returns (bytes memory) {
        return QueryZoraTicksSuperCompact.queryZoraTicksSuperCompact(coin, len, STATE_VIEW);
    }

    function queryZoraTicksSuperCompactOneSide(address coin, bool isLeft) public view returns (bytes memory) {
        return QueryZoraTicksSuperCompact.queryZoraTicksSuperCompactOneSide(coin, STATE_VIEW, isLeft);
    }

    function queryZoraTicksSuperCompactAuto(address coin) public view returns (bytes memory) {
        return QueryZoraTicksSuperCompact.queryZoraTicksSuperCompactAuto(coin, STATE_VIEW);
    }

    // General function for all v4 pools
    function toId(IZoraCoin.PoolKey memory poolKey) public pure returns (bytes32 poolId) {
        return QueryZoraTicksSuperCompact.toId(poolKey);
    }

    // Specifically for Zora
    function getPoolKeyOfZora(address coin) public view returns (IZoraCoin.PoolKey memory) {
        return QueryZoraTicksSuperCompact.getPoolKeyOfZora(coin);
    }

    // Specifically for Zora
    function getSlot0OfZora(address coin)
        public
        view
        returns (int256 liquidity, uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        return QueryZoraTicksSuperCompact.getSlot0OfZora(coin, POOL_MANAGER);
    }

    // Specifically for Fluid
    function queryFluid(address pool, uint256 dexVariables) public view returns (uint256 centerPrice, uint256 rangeShift, uint256 thresholdShift, uint256 centerPriceShift) {
        return QueryFluid.queryFluid(pool, dexVariables);
    }

    // Specifically for FluidLite
    function queryFluidLite(bytes8 dexId) public view returns (QueryFluidLite.DexKey memory dexKey, uint256 centerPrice, uint256 dexVariables, uint256 rangeShift, uint256 thresholdShift, uint256 centerPriceShift) {
        return QueryFluidLite.queryFluidLite(FLUID_LITE_DEX, FLUID_LITE_DEPLOYER_CONTRACT, dexId);
    }

    // Specifically for FluidDexV2D3D4
    function queryFluidDexV2ExchangePricesAndConfig(address token0, address token1) public view returns (uint256 exchangePricesAndConfig0_, uint256 exchangePricesAndConfig1_) {
        return QueryFluidDexV2D3D4.queryFluidDexV2ExchangePricesAndConfig(FLUID_LIQUIDITY, token0, token1);
    }

    // Specifically for FluidDexV2D3D4
    function queryFluidDexV2D3D4TicksSuperCompact(uint256 dexType, bytes32 dexId, uint24 tickSpacing, uint256 len) public view returns (bytes memory) {
        return QueryFluidDexV2D3D4.queryFluidDexV2D3D4TicksSuperCompact(FLUID_DEX_V2, dexType, dexId, tickSpacing, len);
    }

    // Specifically for FluidDexV2D3D4
    function queryFluidDexV2D3D4TickBitmap(uint256 dexType, bytes32 dexId, int16 startWordPos, int16 endWordPos) public view returns (bytes memory) {
        return QueryFluidDexV2D3D4.queryFluidDexV2D3D4TickBitmap(FLUID_DEX_V2, dexType, dexId, startWordPos, endWordPos);
    }

    // Specifically for Ekubo
    function queryEkuboTicksSuperCompactByTokens(
        address token0,
        address token1,
        bytes32 config
    ) public view returns (bytes memory) {
        return QueryEkuboTicksSuperCompact.queryEkuboTicksSuperCompactByTokens(EKUBO_CORE, token0, token1, config);
    }
}
