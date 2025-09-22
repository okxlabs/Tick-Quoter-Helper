interface IBinPoolManager {
    type PoolId is bytes32;

    /// @notice Get the current value in slot0 of the given pool
    function getSlot0(PoolId id) external view returns (uint24 activeId, uint24 protocolFee, uint24 lpFee);

    /// @notice Returns the reserves of a bin
    /// @param id The id of the bin
    /// @return binReserveX The reserve of token X in the bin
    /// @return binReserveY The reserve of token Y in the bin
    /// @return binLiquidity The total liquidity in the bin
    /// @return totalShares The total shares minted in the bin
    function getBin(PoolId id, uint24 binId)
        external
        view
        returns (uint128 binReserveX, uint128 binReserveY, uint256 binLiquidity, uint256 totalShares);

    /// @notice Returns the next non-empty bin
    /// @dev The next non-empty bin is the bin with a higher (if swapForY is true) or lower (if swapForY is false)
    ///     id that has a non-zero reserve of token X or Y.
    /// @param swapForY Whether the swap is for token Y (true) or token X (false)
    /// @param id The id of the bin
    /// @return nextId The id of the next non-empty bin
    function getNextNonEmptyBin(PoolId id, bool swapForY, uint24 binId) external view returns (uint24 nextId);
}