// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interface/IAlgebraPool.sol";
import "../interface/ICLPoolManager.sol";
import "../interface/IHooks.sol";
import "../interface/IHorizonPool.sol";
import "../interface/IPoolManager.sol";
import "../interface/IPositionManager.sol";
import "../interface/IStateView.sol";
import "../interface/IUniswapV3Pool.sol";
import "../interface/IZora.sol";
import "../interface/IZumiPool.sol";

import {GasReserveCalcLib as GRC} from "./GasReserveCalcLib.sol";

library QueryZoraTicksSuperCompact {
    bytes32 internal constant POOLS_SLOT = bytes32(uint256(6));
    uint256 internal constant MAX_TICKS = 4000;
    
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

    function queryZoraTicksSuperCompact(
        address coin,
        uint256 len,
        address STATE_VIEW
    ) public view returns (bytes memory) {
        SuperVar memory tmp;
        IZoraCoin.PoolKey memory poolkey = IZoraCoin(coin).getPoolKey();
        tmp.tickSpacing = poolkey.tickSpacing;
        bytes32 poolId = toId(poolkey);
        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) =
                IStateView(STATE_VIEW).getSlot0(statePoolId);
            tmp.currTick = tick;
        }

        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position().
        // NOTE: Solidity division truncates toward zero, so negative ticks need floor adjustment.
        int24 compressed = tmp.currTick / tmp.tickSpacing;
        if (tmp.currTick < 0 && (tmp.currTick % tmp.tickSpacing != 0)) {
            compressed--;
        }
        tmp.right = compressed >> 8;
        tmp.leftMost = -887_272 / tmp.tickSpacing / int24(256) - 2;
        tmp.rightMost = 887_272 / tmp.tickSpacing / int24(256) + 1;

        tmp.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        tmp.initPoint2 = tmp.initPoint;

        // Pre-allocate to avoid O(n^2) bytes.concat; we will trim to actual length before return.
        bytes memory tickInfo = new bytes(len * 32);
        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                        (uint128 liquidityGross, int128 liquidityNet) =
                            IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        // Write packed bytes32 directly into the pre-allocated buffer.
                        assembly {
                            mstore(add(tickInfo, add(32, mul(index, 32))), data)
                        }

                        index++;
                    }

                    res = res >> 1;
                }
            }
            tmp.initPoint = 0;
            tmp.right++;
        }

        bool isInitPoint = true;
        while (index < len && tmp.left > tmp.leftMost) {
            uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                        (uint128 liquidityGross, int128 liquidityNet) =
                            IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

                        int256 data = int256(uint256(int256(tick)) << 128)
                            + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                        // Write packed bytes32 directly into the pre-allocated buffer.
                        assembly {
                            mstore(add(tickInfo, add(32, mul(index, 32))), data)
                        }

                        index++;
                    }

                    res = res << 1;
                    if (i == 0) break;
                }
            }
            isInitPoint = false;
            tmp.initPoint2 = 256;
            tmp.left--;
        }
        // Trim array to actual length (no empty content returned).
        assembly {
            mstore(tickInfo, mul(index, 32))
        }
        return tickInfo;
    }

    /// @notice Optimized auto version with gas-based termination and alternating query
    /// @param coin The Zora coin address
    /// @param STATE_VIEW The state view contract address
    /// @return tickInfo Packed tick data (tick << 128 | liquidityNet)
    function queryZoraTicksSuperCompactAuto(
        address coin,
        address STATE_VIEW
    ) public view returns (bytes memory) {
        SuperVar memory tmp;
        IZoraCoin.PoolKey memory poolkey = IZoraCoin(coin).getPoolKey();
        tmp.tickSpacing = poolkey.tickSpacing;
        bytes32 poolId = toId(poolkey);
        IStateView.PoolId statePoolId = IStateView.PoolId.wrap(poolId);

        {
            (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) =
                IStateView(STATE_VIEW).getSlot0(statePoolId);
            tmp.currTick = tick;
        }

        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position().
        int24 compressed = tmp.currTick / tmp.tickSpacing;
        if (tmp.currTick < 0 && (tmp.currTick % tmp.tickSpacing != 0)) {
            compressed--;
        }
        tmp.right = compressed >> 8;
        tmp.leftMost = -887_272 / tmp.tickSpacing / int24(256) - 2;
        tmp.rightMost = 887_272 / tmp.tickSpacing / int24(256) + 1;

        tmp.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        tmp.initPoint2 = tmp.initPoint;

        // Pre-allocate fixed size array to avoid O(n²) bytes.concat
        bytes memory tickInfo = new bytes(MAX_TICKS * 32);
        uint256 tickCount = 0;

        tmp.left = tmp.right;

        // Alternating query: query right and left by word to balance tick range
        bool canQueryRight = true;
        bool canQueryLeft = true;
        bool isLeftInitPoint = true;

        while (gasleft() > GRC.calcGasReserve(tickCount) && (canQueryRight || canQueryLeft) && tickCount < MAX_TICKS) {
            // Query one word on the right side
            if (canQueryRight && tmp.right < tmp.rightMost && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS) {
                uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.right));
                if (res > 0) {
                    res = res >> tmp.initPoint;
                    for (uint256 i = tmp.initPoint; i < 256 && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS; i++) {
                        uint256 isInit = res & 0x01;
                        if (isInit > 0) {
                            int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);

                            (uint128 liquidityGross, int128 liquidityNet) =
                                IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

                            int256 data = int256(uint256(int256(tick)) << 128)
                                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                            // Write directly to pre-allocated memory position
                            assembly {
                                mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                            }
                            tickCount++;
                        }
                        res = res >> 1;
                    }
                }
                tmp.initPoint = 0;
                tmp.right++;
                canQueryRight = tmp.right < tmp.rightMost;
            } else {
                canQueryRight = false;
            }

            // Query one word on the left side
            if (canQueryLeft && tmp.left > tmp.leftMost && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS) {
                uint256 res = IStateView(STATE_VIEW).getTickBitmap(statePoolId, int16(tmp.left));
                if (res > 0 && tmp.initPoint2 != 0) {
                    res = isLeftInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                    for (uint256 i = tmp.initPoint2 - 1; i >= 0 && gasleft() > GRC.calcGasReserve(tickCount) && tickCount < MAX_TICKS; i--) {
                        uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                        if (isInit > 0) {
                            int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);

                            (uint128 liquidityGross, int128 liquidityNet) =
                                IStateView(STATE_VIEW).getTickLiquidity(statePoolId, int24(int256(tick)));

                            int256 data = int256(uint256(int256(tick)) << 128)
                                + (int256(liquidityNet) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
                            // Write directly to pre-allocated memory position
                            assembly {
                                mstore(add(tickInfo, add(32, mul(tickCount, 32))), data)
                            }
                            tickCount++;
                        }
                        res = res << 1;
                        if (i == 0) break;
                    }
                }
                isLeftInitPoint = false;
                tmp.initPoint2 = 256;
                tmp.left--;
                canQueryLeft = tmp.left > tmp.leftMost;
            } else {
                canQueryLeft = false;
            }
        }

        // Trim array to actual length (no empty content returned)
        assembly {
            mstore(tickInfo, mul(tickCount, 32))
        }
        return tickInfo;
    }

    // General function for all v4 pools

    function toId(IZoraCoin.PoolKey memory poolKey) public pure returns (bytes32 poolId) {
        assembly ("memory-safe") {
            // 0xa0 represents the total size of the poolKey struct (5 slots of 32 bytes)
            poolId := keccak256(poolKey, 0xa0)
        }
    }

    // Specifically for Zora
    function getPoolKeyOfZora(address coin)
        public
        view
        returns (IZoraCoin.PoolKey memory)
    {
        IZoraCoin.PoolKey memory poolKey = IZoraCoin(coin).getPoolKey();
        return poolKey;
    }

    // Specifically for Zora
    function getSlot0OfZora(address coin, address POOL_MANAGER)
        public
        view
        returns (int256 liquidity, uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        IZoraCoin.PoolKey memory poolKey = IZoraCoin(coin).getPoolKey();
        bytes32 poolId = toId(poolKey);
        bytes32 slot = _getPoolStateSlot(poolId);
        bytes32[] memory slot0 = IPoolManager(POOL_MANAGER).extsload(slot, 4);
        bytes32 data = slot0[0];
        liquidity = int256(uint256(slot0[3]));

        //   24 bits  |24bits|24bits      |24 bits|160 bits
        // 0x000000   |000bb8|000000      |ffff75 |0000000000000000fe3aa841ba359daa0ea9eff7
        // ---------- | fee  |protocolfee | tick  | sqrtPriceX96
        assembly ("memory-safe") {
            // bottom 160 bits of data
            sqrtPriceX96 := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            // next 24 bits of data
            tick := signextend(2, shr(160, data))
            // next 24 bits of data
            protocolFee := and(shr(184, data), 0xFFFFFF)
            // last 24 bits of data
            lpFee := and(shr(208, data), 0xFFFFFF)
        }
    }

    function _getPoolStateSlot(bytes32 poolId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(poolId, POOLS_SLOT));
    }
}
