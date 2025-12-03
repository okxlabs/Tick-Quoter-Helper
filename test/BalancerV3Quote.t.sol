// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import {BalancerV3Quoter, IVault, IERC20, IQuantAMMWeightedPool} from "../src/Balancer/BalancerV3Quoter.sol";
import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BalancerV3QuoteTest is Test {
    BalancerV3Quoter quoter;

    // Balancer V3 Vault address (Base network)
    address constant VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    // Test pool addresses (Base network Balancer V3 pools)
    address constant QUANTAMM_POOL = 0xb4161AeA25BD6C5c8590aD50deB4Ca752532F05D; // QuantAMM WeightedPool
    address constant WEIGHTED_POOL = 0x4Fbb7870DBE7A7Ef4866A33c0eED73D395730dc0; // Standard WeightedPool
    address constant STABLE_POOL = 0x7AB124EC4029316c2A42F713828ddf2a192B36db; // StablePool (with hook)
    address constant FAIL_POOL = 0x8056adDb74F5dA49b697984E3B464Dec0F72583c; // Fail pool (no hook)

    function setUp() public {
        // Fork Base network for testing
        vm.createSelectFork("https://base.lava.build");

        // Deploy the implementation contract (no constructor now)
        BalancerV3Quoter implementation = new BalancerV3Quoter();
        
        // Prepare initialization data (no parameters needed)
        bytes memory initData = abi.encodeWithSelector(
            BalancerV3Quoter.initialize.selector
        );
        
        // Deploy proxy and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        quoter = BalancerV3Quoter(address(proxy));
    }

    function test_getTotalSupply() public {
        uint256 totalSupply = quoter.getTotalSupply(QUANTAMM_POOL);
        console2.log(totalSupply);
    }

    function test_getPoolData() public {
        string memory pool_type;
        BalancerV3Quoter.WeightedPoolData memory weightedData;
        BalancerV3Quoter.StablePoolData memory stableData;
        uint256[] memory balancesRaw;
        (pool_type, weightedData, stableData, balancesRaw) = quoter.getPoolData(QUANTAMM_POOL);
        console2.log(pool_type);
        console2.log(weightedData.immutableData.tokens.length);
        console2.log(stableData.immutableData.tokens.length);
        console2.log(balancesRaw.length);
    }

    function test_getPoolData_fail() public {
        string memory pool_type;
        BalancerV3Quoter.WeightedPoolData memory weightedData;
        BalancerV3Quoter.StablePoolData memory stableData;
        uint256[] memory balancesRaw;
        (pool_type, weightedData, stableData, balancesRaw) = quoter.getPoolData(FAIL_POOL);
        console2.log(pool_type);
        console2.log(weightedData.immutableData.tokens.length);
        console2.log(stableData.immutableData.tokens.length);
        console2.log(balancesRaw.length);
    }
}
