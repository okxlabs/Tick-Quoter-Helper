pragma solidity 0.8.17;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import {QueryData} from "../src/Quote.sol";

contract AlgebraIntegralTest is Test {
    QueryData quoter;

    address constant BLACK_HOLE_V3_POOL = 0x1B4d11Ab4658744714D1A6D6633247eFBd816be5;

    function setUp() public {
        vm.createSelectFork("https://avax-mainnet.g.alchemy.com/v2/Vi9EBxKbLyTvKM3I2LXvsOV8f6fWsbrj", 75590154);
        quoter = new QueryData();
        quoter.initialize();
    }

    function test_queryAlgebraTicksSuperCompact2_v2() public {
        QueryData quoter = new QueryData();
        quoter.initialize();
        bytes memory ticks = quoter.queryAlgebraTicksSuperCompact2_v2(BLACK_HOLE_V3_POOL, 20);
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