interface IPoolManager {
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory);
}
