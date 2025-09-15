pragma solidity 0.8.28;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import {QueryEkubo} from "../src/QueryEkubo.sol";

contract Deploy is Test {
    address CORE = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;
    
    QueryEkubo quoter;
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        vm.startBroadcast(deployer);
        require(block.chainid == 1, "must be right chain");
        quoter = new QueryEkubo(CORE);
        console2.log("query address", address(quoter));
        vm.stopBroadcast();
    }
}