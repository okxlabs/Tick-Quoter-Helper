// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import {QueryData} from "../src/Quote.sol";
import {QueryFluidDexV2D3D4} from "../src/extLib/QueryFluidDexV2D3D4.sol";


interface IFluidDexV2Resolver {
    struct DexKey {
        address token0;
        address token1;
        uint24 fee; // The fee here tells the fee if its a static fee pool or acts as a dynamic fee flag, i.e, type(uint24).max or 0xFFFFFF for dynamic fee pools.
        uint24 tickSpacing;
        address controller;
    }

    struct TickLiquidity {
        int24 tick;
        uint256 liquidity;
    }

    struct DexVariables {
        int256 currentTick;
        uint256 currentSqrtPriceX96;
        uint256 feeGrowthGlobal0X102;
        uint256 feeGrowthGlobal1X102;
    }

    struct DexVariables2 {
        uint256 protocolFee0To1;
        uint256 protocolFee1To0;
        uint256 protocolCutFee;
        uint256 token0Decimals;
        uint256 token1Decimals;
        uint256 activeLiquidity;
        bool poolAccountingFlag; // 0 = per pool accounting ON, 1 = per pool accounting OFF
        bool fetchDynamicFeeFlag;
        uint256 feeVersion; // 0 = static fee, 1 = inbuilt dynamic fee
        uint256 lpFee;
        uint256 maxDecayTime;
        uint256 priceImpactToFeeDivisionFactor;
        uint256 minFee;
        uint256 maxFee;
        int256 netPriceImpact;
        uint256 lastUpdateTimestamp;
        uint256 decayTimeRemaining;
    }

    struct DexPoolStateRaw {
        uint256 dexVariablesPacked;
        uint256 dexVariables2Packed;
        DexVariables dexVariablesUnpacked;
        DexVariables2 dexVariables2Unpacked;
    }

    struct DexPoolState {
        bytes32 dexId;
        uint256 dexPriceParsed;
        DexPoolStateRaw dexPoolStateRaw;
    }

    function getDexKey(uint256 dexType_, bytes32 dexId_) external view returns (DexKey memory dexKey_);

    function getDexPoolState(uint256 dexType_, DexKey memory dexKey_) external view returns (DexPoolState memory dexPoolState_);

    function getLiquidityAmounts(
        uint256 dexType_,
        DexKey memory dexKey_,
        int24 startTick_,
        int24 endTick_,
        uint256 startLiquidity_
    ) external view returns (TickLiquidity[] memory tickLiquidities_);
}

contract FluidDexV2D3D4LibTest is Test {
    QueryData quoter;
    address fluidDexV2Resolver = 0x1E45589D501AcED82013c2838552122f943B33Ac;

    function setUp() public {
        vm.createSelectFork("https://polygon-mainnet.g.alchemy.com/v2/aMbWrR8EcmCGpF6rCSNk0P24wTZbbG7R", 79900990);
        quoter = new QueryData();
        quoter.initialize();
    }

    // There are 4 pools for testing:
    // - dexType: 3, dexId: 0xBC4435ED6FCF5FE373CDB243A3E5685F49DBDE7D3D91BFF4806CC064F9EFD11E
    // - dexType: 4, dexId: 0xBC4435ED6FCF5FE373CDB243A3E5685F49DBDE7D3D91BFF4806CC064F9EFD11E
    // - dexType: 3, dexId: 0x8D1B5F8DA63FA29B191672231D3845740A11FCBEF6C76E077CFFFE56CC27C707
    // - dexType: 4, dexId: 0x8D1B5F8DA63FA29B191672231D3845740A11FCBEF6C76E077CFFFE56CC27C707

    function test_queryFromFluidDexV2Resolver() public {
        uint256 startLiquidity = 10 ** 18;

        uint256 dexType = 3;
        bytes32 dexId = 0xBC4435ED6FCF5FE373CDB243A3E5685F49DBDE7D3D91BFF4806CC064F9EFD11E;

        IFluidDexV2Resolver.DexKey memory dexKey = IFluidDexV2Resolver(fluidDexV2Resolver).getDexKey(dexType, dexId);
        console2.log("tickSpacing:", dexKey.tickSpacing);

        // Call FluidDexV2Resolver to compare
        IFluidDexV2Resolver.DexPoolState memory dexPoolState = IFluidDexV2Resolver(fluidDexV2Resolver).getDexPoolState(dexType, dexKey);
        int24 currentTick = int24(dexPoolState.dexPoolStateRaw.dexVariablesUnpacked.currentTick);
        console2.log("currentTick:", currentTick);

        int24 tickSpacing = int24(dexKey.tickSpacing);
        int24 startTick = (currentTick/tickSpacing) * tickSpacing - 20 * tickSpacing;
        int24 endTick = (currentTick/tickSpacing) * tickSpacing + 20 * tickSpacing;
        console2.log("startTick:", startTick);
        console2.log("endTick:", endTick);

        IFluidDexV2Resolver.TickLiquidity[] memory tickLiquidities = IFluidDexV2Resolver(fluidDexV2Resolver).getLiquidityAmounts(dexType, dexKey, startTick, endTick, startLiquidity);
        console2.log("tickLiquidities:");
        console2.log("- length:", tickLiquidities.length);
        console2.log("--------------------------------");
        for (uint256 i = 1; i < tickLiquidities.length; i++) {
            console2.log("-----");
            console2.log("- tick:", int24(tickLiquidities[i].tick));
            int256 liquidityNet = int256(tickLiquidities[i].liquidity) - int256(tickLiquidities[i-1].liquidity);
            console2.log("- liquidityNet:", liquidityNet);
        }
    }

    function test_queryFluidDexV2D3D4TickBitmap() public {
        uint256 dexType = 3;
        bytes32 dexId = 0xBC4435ED6FCF5FE373CDB243A3E5685F49DBDE7D3D91BFF4806CC064F9EFD11E;

        IFluidDexV2Resolver.DexKey memory dexKey = IFluidDexV2Resolver(fluidDexV2Resolver).getDexKey(dexType, dexId);
        IFluidDexV2Resolver.DexPoolState memory dexPoolState = IFluidDexV2Resolver(fluidDexV2Resolver).getDexPoolState(dexType, dexKey);
        int24 currentTick = int24(dexPoolState.dexPoolStateRaw.dexVariablesUnpacked.currentTick);
        int24 tickSpacing = int24(dexKey.tickSpacing);
        console2.log("currentTick:", currentTick);
        console2.log("tickSpacing:", tickSpacing);

        int16 currentWordPos = int16(currentTick / tickSpacing / 256);
        console2.log("currentWordPos:", currentWordPos);
        int16 startWordPos = currentWordPos - 100;
        int16 endWordPos = currentWordPos + 100;
        console2.log("startWordPos:", startWordPos);
        console2.log("endWordPos:", endWordPos);
        bytes memory tickBitmap = quoter.queryFluidDexV2D3D4TickBitmap(3, dexId, startWordPos, endWordPos);
        require(tickBitmap.length == uint256(int256(endWordPos - startWordPos + 1)) * 32, "tickBitmap length is not correct");
        console2.log("tickBitmap:");
        // console2.logBytes(tickBitmap);

        for (uint256 i = 0; i < tickBitmap.length / 32; i++) {
            bytes32 data;
            uint256 offset = i * 32;
            assembly {
                data := mload(add(add(tickBitmap, 0x20), offset))
            }
            
            // calculate word pos
            int16 wordPos = startWordPos + int16(int256(i));
            uint256 bitmap = uint256(data);
            
            // console2.log("---");
            // console2.log("word pos:", wordPos);
            // if (bitmap > 0) {
            //     console2.log("bitmap value:");
            //     console2.logBytes32(data);
            // } else {
            //     console2.log("bitmap value: 0");
            // }
            
            // iterate through each bit in the current word (256 bits)
            if (bitmap > 0) {
                for (uint256 bitIndex = 0; bitIndex < 256; bitIndex++) {
                    uint256 isInit = (bitmap >> bitIndex) & 0x01;
                    
                    // if the current bit is 0, then the tick is not initialized
                    if (isInit > 0) {
                        // calculate tick value: tick = (256 * wordPos + bitIndex) * tickSpacing
                        int256 tick = int256((256 * int256(wordPos) + int256(bitIndex)) * int256(tickSpacing));
                        console2.log("  [initialized] tick:", tick);
                    }
                }
            }
        }
    }

    function test_queryFluidDexV2ExchangePricesAndConfig() public {
        (uint256 exchangePricesAndConfig0_, uint256 exchangePricesAndConfig1_) = quoter.queryFluidDexV2ExchangePricesAndConfig(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359, 0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
        console2.log("exchangePricesAndConfig0_:", exchangePricesAndConfig0_);
        console2.log("exchangePricesAndConfig1_:", exchangePricesAndConfig1_);
    }

    function test_queryFluidDexV2D3D4TicksSuperCompact() public {
        uint256 dexType = 3;
        bytes32 dexId = 0xBC4435ED6FCF5FE373CDB243A3E5685F49DBDE7D3D91BFF4806CC064F9EFD11E;

        IFluidDexV2Resolver.DexKey memory dexKey = IFluidDexV2Resolver(fluidDexV2Resolver).getDexKey(dexType, dexId);
        IFluidDexV2Resolver.DexPoolState memory dexPoolState = IFluidDexV2Resolver(fluidDexV2Resolver).getDexPoolState(dexType, dexKey);

        bytes memory ticks = quoter.queryFluidDexV2D3D4TicksSuperCompact(dexType, dexId, dexKey.tickSpacing, 10);
        console2.log("ticks:");
        console2.logBytes(ticks);
        
        // decode tick and liquidityNet
        // encoding rule: each 32 bytes contains a tick information, the high 128 bits is tick, the low 128 bits is liquidityNet
        console2.log("\n=== decode tick and liquidityNet ===");
        require(ticks.length % 32 == 0, "ticks length is not divisible by 32");
        uint256 tickCount = ticks.length / 32;
        console2.log("tick count:", tickCount);
        
        for (uint256 i = 0; i < tickCount; i++) {
            bytes32 data;
            uint256 offset = i * 32;
            
            // extract 32 bytes from bytes
            assembly {
                data := mload(add(add(ticks, 0x20), offset))
            }
            
            // decode tick (high 128 bits, signed)
            int256 tick = int256(int128(uint128(uint256(data) >> 128)));
            
            // decode liquidityNet (low 128 bits, signed)
            int256 liquidityNet = int256(int128(uint128(uint256(data) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff)));
            
            console2.log("---");
            console2.log("index:", i);
            console2.log("tick:", tick);
            console2.log("liquidityNet:", liquidityNet);
        }
    }
}