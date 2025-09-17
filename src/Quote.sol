// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

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
/// @title DexNativeRouter
/// @notice Entrance of trading native token in web3-dex

contract QueryData {
    address public immutable POOL_MANAGER;
    address public immutable STATE_VIEW;
    address public immutable POSITION_MANAGER;

    int24 internal constant MIN_TICK_MINUS_1 = -887_272 - 1;
    int24 internal constant MAX_TICK_PLUS_1 = 887_272 + 1;
    bytes32 public constant POOLS_SLOT = bytes32(uint256(6));
    address public constant PANCAKE_INFINITY_CLPOOLMANAGER = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
    address public constant PANCAKE_INFINITY_POSITION_MANAGER = 0x55f4c8abA71A1e923edC303eb4fEfF14608cC226;
    uint256 internal constant OFFSET_TICK_SPACING = 16;

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
            poolId, len, POOL_MANAGER, STATE_VIEW, POSITION_MANAGER
        );
    }

    function queryPancakeInfinityTicksSuperCompact(bytes32 poolId, uint256 len) public view returns (bytes memory) {
        return QueryUniv4TicksSuperCompact.queryPancakeInfinityTicksSuperCompact(
            poolId, len, POOL_MANAGER, STATE_VIEW, POSITION_MANAGER
        );
    }

    function queryZoraTicksSuperCompact(address coin, uint256 len) public view returns (bytes memory) {
        return
            QueryZoraTicksSuperCompact.queryZoraTicksSuperCompact(coin, len, POOL_MANAGER, STATE_VIEW, POSITION_MANAGER);
    }

    // General function for all v4 pools
    function toId(IZoraCoin.PoolKey memory poolKey) public pure returns (bytes32 poolId) {
        return QueryZoraTicksSuperCompact.toId(poolKey);
    }

    // Specifically for Zora
    function getPoolKeyOfZora(address coin) public view returns (IZoraCoin.PoolKey memory) {
        return QueryZoraTicksSuperCompact.getPoolKeyOfZora(coin, POOL_MANAGER, STATE_VIEW, POSITION_MANAGER);
    }

    // Specifically for Zora
    function getSlot0OfZora(address coin)
        public
        view
        returns (int256 liquidity, uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        return QueryZoraTicksSuperCompact.getSlot0OfZora(coin, POOL_MANAGER, STATE_VIEW, POSITION_MANAGER);
    }
}
