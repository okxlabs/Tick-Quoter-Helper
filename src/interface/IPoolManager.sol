// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPoolManager {
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory);
}
