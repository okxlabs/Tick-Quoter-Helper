// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    IFluidLiquidity,
    IFluidDexV2,
    LiquiditySlotsLink as LSL,
    DexV2D3D4CommonSlotsLink as DSL
} from "../interface/IFluidDexV2D3D4.sol";

import "forge-std/console2.sol";

library QueryFluidDexV2D3D4 {
    // ==================== Constants ====================
    // Copy from https://polygonscan.com/address/0x731736537F451c59E1eEafB9Ed14295381203C2f#code#F19#L58
    int24 internal constant MIN_TICK = -524287; // Not -887272
    int24 internal constant MAX_TICK = -MIN_TICK;

    // Copy from https://polygonscan.com/address/0x2Ba521a909BDBE56183e3cd5F27962466e674610#code#F15#L11
    uint256 internal constant X1 = 0x1;
    uint256 internal constant X19 = 0x7FFFF;

    uint256 internal constant D3_DEX_TYPE = 3;
    uint256 internal constant D4_DEX_TYPE = 4;

    // ==================== External Functions ====================
    struct DexKey {
        address token0;
        address token1;
        uint24 fee; // The fee here tells the fee if its a static fee pool or acts as a dynamic fee flag, i.e, type(uint24).max or 0xFFFFFF for dynamic fee pools.
        uint24 tickSpacing;
        address controller;
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

    function queryFluidDexV2ExchangePricesAndConfig(
        address liquidity,
        address token0,
        address token1
    ) public view returns (uint256 exchangePricesAndConfig0_, uint256 exchangePricesAndConfig1_) {
        if (token0 != address(0)) {
            bytes32 slot = LSL.calculateMappingStorageSlot(LSL.LIQUIDITY_EXCHANGE_PRICES_MAPPING_SLOT, token0);
            exchangePricesAndConfig0_ = IFluidLiquidity(liquidity).readFromStorage(slot);
        }
        if (token1 != address(0)) {
            bytes32 slot = LSL.calculateMappingStorageSlot(LSL.LIQUIDITY_EXCHANGE_PRICES_MAPPING_SLOT, token1);
            exchangePricesAndConfig1_ = IFluidLiquidity(liquidity).readFromStorage(slot);
        }
    }

    function queryFluidDexV2D3D4TicksSuperCompact(
        address fluidDexV2,
        uint256 dexType,
        bytes32 dexId,
        uint24 tickSpacing,
        uint256 len
    ) public view returns (bytes memory) {
        require(dexType == D3_DEX_TYPE || dexType == D4_DEX_TYPE, "Invalid dex type");

        SuperVar memory tmp;
        tmp.tickSpacing = int24(tickSpacing);
        tmp.currTick = _getCurrentTick(fluidDexV2, dexType, dexId);

        // Calculate starting word/bit position aligned with Uniswap V3 TickBitmap.position().
        // NOTE: Solidity division truncates toward zero, so negative ticks need floor adjustment.
        int24 compressed = tmp.currTick / tmp.tickSpacing;
        if (tmp.currTick < 0 && (tmp.currTick % tmp.tickSpacing != 0)) {
            compressed--;
        }
        tmp.right = compressed >> 8;
        tmp.leftMost = MIN_TICK / tmp.tickSpacing / int24(256) - 2;
        tmp.rightMost = MAX_TICK / tmp.tickSpacing / int24(256) + 1;

        tmp.initPoint = uint256(uint256(int256(compressed)) & 0xff);
        tmp.initPoint2 = tmp.initPoint;

        // Pre-allocate to avoid O(n^2) bytes.concat; we will trim to actual length before return.
        bytes memory tickInfo = new bytes(len * 32);

        tmp.left = tmp.right;

        uint256 index = 0;

        while (index < len / 2 && tmp.right < tmp.rightMost) {
            uint256 res = _getTickBitmap(fluidDexV2, dexType, dexId, int16(tmp.right));
            if (res > 0) {
                res = res >> tmp.initPoint;
                for (uint256 i = tmp.initPoint; i < 256 && index < len / 2; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.right + int256(i)) * tmp.tickSpacing);
                        int256 liquidityNet = _getTickLiquidityNet(fluidDexV2, dexType, dexId, int24(tick));
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
            uint256 res = _getTickBitmap(fluidDexV2, dexType, dexId, int16(tmp.left));
            if (res > 0 && tmp.initPoint2 != 0) {
                res = isInitPoint ? res << ((256 - tmp.initPoint2) % 256) : res;
                for (uint256 i = tmp.initPoint2 - 1; i >= 0 && index < len; i--) {
                    uint256 isInit = res & 0x8000000000000000000000000000000000000000000000000000000000000000;
                    if (isInit > 0) {
                        int256 tick = int256((256 * tmp.left + int256(i)) * tmp.tickSpacing);
                        int256 liquidityNet = _getTickLiquidityNet(fluidDexV2, dexType, dexId, int24(tick));
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

    function queryFluidDexV2D3D4TickBitmap(
        address fluidDexV2,
        uint256 dexType,
        bytes32 dexId,
        int16 startWordPos,
        int16 endWordPos
    ) public view returns (bytes memory) {
        require(dexType == D3_DEX_TYPE || dexType == D4_DEX_TYPE, "Invalid dex type");
        require(startWordPos <= endWordPos, "Invalid word position");
        
        int256 wordsSigned = int256(endWordPos) - int256(startWordPos) + 1;
        // Pre-allocate to avoid O(n^2) bytes.concat; we will trim to actual length before return.
        bytes memory tickBitmap = new bytes(uint256(wordsSigned) * 32);
        uint256 index = 0;
        for (int16 wordPos = startWordPos; wordPos <= endWordPos; wordPos++) {
            uint256 res = _getTickBitmap(fluidDexV2, dexType, dexId, wordPos);
            assembly {
                mstore(add(tickBitmap, add(32, mul(index, 32))), res)
            }
            index++;
        }
        // Trim array to actual length (no empty content returned).
        assembly {
            mstore(tickBitmap, mul(index, 32))
        }
        return tickBitmap;
    }

    // ==================== Internal Functions ====================
    function _getCurrentTick(
        address fluidDexV2_,
        uint256 dexType_,
        bytes32 dexId_
    ) internal view returns (int24) {
        bytes32 slot = DSL.calculateDoubleMappingStorageSlot(DSL.DEX_V2_VARIABLES_SLOT, bytes32(dexType_), dexId_);
        uint256 dexVariablesPacked_ = IFluidDexV2(fluidDexV2_).readFromStorage(slot);
        int256 currentTick_ = int256((dexVariablesPacked_ >> DSL.BITS_DEX_V2_VARIABLES_ABSOLUTE_CURRENT_TICK) & X19);
        if ((dexVariablesPacked_ >> DSL.BITS_DEX_V2_VARIABLES_CURRENT_TICK_SIGN) & X1 == 0) {
            currentTick_ = -currentTick_;
        }
        return int24(currentTick_);
    }

    function _getTickBitmap(
        address fluidDexV2_,
        uint256 dexType_,
        bytes32 dexId_,
        int16 wordPos_
    ) internal view returns (uint256) {
        bytes32 slot_ = DSL.calculateTripleMappingStorageSlot(
            DSL.DEX_V2_TICK_BITMAP_MAPPING_SLOT, 
            bytes32(dexType_), 
            dexId_, 
            bytes32(uint256(int256(wordPos_)))
        );
        return uint256(IFluidDexV2(fluidDexV2_).readFromStorage(slot_));
    }

    function _getTickLiquidityNet(
        address fluidDexV2_,
        uint256 dexType_,
        bytes32 dexId_,
        int24 tick_
    ) internal view returns (int256) {
        bytes32 baseSlot_ = DSL.calculateTripleMappingStorageSlot(
            DSL.DEX_V2_TICK_DATA_MAPPING_SLOT, 
            bytes32(dexType_), 
            dexId_, 
            bytes32(uint256(int256(tick_)))
        );
        
        // liquidityNet is at baseSlot_ + 0
        return int256(IFluidDexV2(fluidDexV2_).readFromStorage(baseSlot_));
    }
}