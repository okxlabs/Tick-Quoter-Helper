// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/Quote.sol";

/**
 * @dev Before running, use `node scripts/prepare_deploy.js <chain>` to set addresses
 */
contract Deploy is Script {
    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Deploying QueryData ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerKey);
        
        QueryData implementation = new QueryData();
        console2.log("QueryData deployed at:", address(implementation));
        
        vm.stopBroadcast();
    }
}
