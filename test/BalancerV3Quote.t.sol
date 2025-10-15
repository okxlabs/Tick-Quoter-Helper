// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import {BalancerV3Quoter, IVault, IERC20, IQuantAMMWeightedPool} from "../src/Balancer/BalancerV3Quoter.sol";

// Test version that doesn't disable initializers
contract BalancerV3QuoterTest is BalancerV3Quoter {
    // Override constructor to not disable initializers for testing
    constructor() {
        // Don't call _disableInitializers() for testing
    }
}

contract BalancerV3QuoteTest is Test {
    BalancerV3QuoterTest quoter;

    // Balancer V3 Vault address (Base network)
    address constant VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    // Test pool addresses (Base network Balancer V3 pools)
    address constant QUANTAMM_POOL = 0xb4161AeA25BD6C5c8590aD50deB4Ca752532F05D; // QuantAMM WeightedPool
    address constant WEIGHTED_POOL = 0x4Fbb7870DBE7A7Ef4866A33c0eED73D395730dc0; // Standard WeightedPool
    address constant STABLE_POOL = 0x7AB124EC4029316c2A42F713828ddf2a192B36db; // StablePool (with hook)

    function setUp() public {
        // Fork Base network for testing
        vm.createSelectFork("https://base.lava.build");

        // Deploy the quoter and initialize it
        quoter = new BalancerV3QuoterTest();
        quoter.initialize(VAULT, address(this));
    }

    function test_getPoolData() public {
        string memory pool_type;
        BalancerV3Quoter.WeightedPoolData memory weightedData;
        BalancerV3Quoter.StablePoolData memory stableData;
        uint256[] memory balancesRaw;
        (pool_type, weightedData, stableData, balancesRaw) = quoter.getPoolData(QUANTAMM_POOL);
    }
}
