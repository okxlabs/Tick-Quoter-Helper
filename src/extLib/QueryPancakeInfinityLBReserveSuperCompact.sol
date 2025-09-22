// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interface/IBinPoolManager.sol";

library QueryPancakeInfinityLBReserveSuperCompact {
    address public constant PANCAKE_INFINITY_LBPOOLMANAGER = 0xC697d2898e0D09264376196696c51D7aBbbAA4a9;

    function queryPancakeInfinityLBReserve(bytes32 poolId)
        public
        view
        returns (uint256 totalReserveX, uint256 totalReserveY)
    {
        IBinPoolManager.PoolId lbPoolId = IBinPoolManager.PoolId.wrap(poolId);
        uint24 minBinId = IBinPoolManager(PANCAKE_INFINITY_LBPOOLMANAGER).getNextNonEmptyBin(lbPoolId, false, 1);
        uint24 maxBinId = IBinPoolManager(PANCAKE_INFINITY_LBPOOLMANAGER).getNextNonEmptyBin(lbPoolId, true, type(uint24).max);
        (uint24 activeId, , ) = IBinPoolManager(PANCAKE_INFINITY_LBPOOLMANAGER).getSlot0(lbPoolId);

        for (uint24 i = minBinId; i <= maxBinId; i++) {
            (uint128 reserveX, uint128 reserveY,,) = IBinPoolManager(PANCAKE_INFINITY_LBPOOLMANAGER).getBin(lbPoolId, i);
            if (i < activeId) {
                totalReserveY += reserveY;
            } else if (i > activeId) {
                totalReserveX += reserveX;
            } else {
                // i == activeId
                totalReserveX += reserveX;
                totalReserveY += reserveY;
            }
        }
    }
}