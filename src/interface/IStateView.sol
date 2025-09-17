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
