/// @notice Tick info library for Pancake Infinity
library Tick {
    struct Info {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }
}

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
