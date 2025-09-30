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

contract QueryData is OwnableUpgradeable {
    // Core contract addresses (Base network)
    address public constant POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address public constant STATE_VIEW = 0xA3c0c9b65baD0b08107Aa264b0f3dB444b867A71;
    address public constant POSITION_MANAGER = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    // FluidLite contract addresses
    address public constant FLUID_LITE_DEX = 0xBbcb91440523216e2b87052A99F69c604A7b6e00;
    address public constant FLUID_LITE_DEPLOYER_CONTRACT = 0x4EC7b668BAF70d4A4b0FC7941a7708A07b6d45Be;

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

    function queryAlgebraTicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact(pool, len);
    }

    function queryAlgebraTicksSuperCompact3_back(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact3_back(pool, len);
    }

    function queryHorizonTicksSuperCompact(address pool, uint256 len) public view returns (bytes memory) {
        return QueryHorizonTicksSuperCompact.queryHorizonTicksSuperCompact(pool, len);
    }

    function queryAlgebraTicksSuperCompact2(address pool, uint256 len) public view returns (bytes memory) {
        return QueryAlgebraTicksSuperCompact.queryAlgebraTicksSuperCompact2(pool, len);
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

    function queryPancakeInfinityTicksSuperCompact(bytes32 poolId, uint256 len) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompact(
            poolId, len
        );
    }

    function queryPancakeInfinityLBReserveSuperCompact(bytes32 poolId) public view returns (uint256 totalReserveX, uint256 totalReserveY) {
        return QueryPancakeInfinityLBReserveSuperCompact.queryPancakeInfinityLBReserve(
            poolId
        );
    }

    function queryZoraTicksSuperCompact(address coin, uint256 len) public view returns (bytes memory) {
        return QueryZoraTicksSuperCompact.queryZoraTicksSuperCompact(coin, len, STATE_VIEW);
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
}
