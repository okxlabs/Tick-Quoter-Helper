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

        (bool s1, bytes memory d1) = PANCAKE_INFINITY_LBPOOLMANAGER.staticcall(abi.encodeWithSelector(IBinPoolManager.getNextNonEmptyBin.selector, lbPoolId, false, uint24(1)));
        require(s1, "err_quoter_pancake_lb_getNextNonEmptyBin_min_failed");
        uint24 minBinId = abi.decode(d1, (uint24));

        (bool s2, bytes memory d2) = PANCAKE_INFINITY_LBPOOLMANAGER.staticcall(abi.encodeWithSelector(IBinPoolManager.getNextNonEmptyBin.selector, lbPoolId, true, type(uint24).max));
        require(s2, "err_quoter_pancake_lb_getNextNonEmptyBin_max_failed");
        uint24 maxBinId = abi.decode(d2, (uint24));

        // Sentinel values: no non-empty bins found, pool has no liquidity
        if (minBinId == 0 || maxBinId == type(uint24).max) {
            return (0, 0);
        }

        (bool s3, bytes memory d3) = PANCAKE_INFINITY_LBPOOLMANAGER.staticcall(abi.encodeWithSelector(IBinPoolManager.getSlot0.selector, lbPoolId));
        require(s3, "err_quoter_pancake_lb_getSlot0_failed");
        (uint24 activeId, , ) = abi.decode(d3, (uint24, uint24, uint24));

        for (uint24 i = minBinId; i <= maxBinId; i++) {
            uint128 reserveX;
            uint128 reserveY;
            try IBinPoolManager(PANCAKE_INFINITY_LBPOOLMANAGER).getBin(lbPoolId, i) returns (uint128 _reserveX, uint128 _reserveY, uint256, uint256) {
                reserveX = _reserveX;
                reserveY = _reserveY;
            } catch {
                revert("err_quoter_pancake_lb_getBin_failed");
            }
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