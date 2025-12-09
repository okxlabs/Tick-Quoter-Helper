// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/Quote.sol";

// Cmd: forge script script/DeployQuote.s.sol:Deploy --rpc-url <RPC_URL> (--broadcast) -vvv --private-key <PRIVATE_KEY>

contract Deploy is Script {
    QueryData quoter;
    address deployer;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying from address:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployer);
        
        console2.log("Deploying QueryData contract...");
        quoter = new QueryData();
        console2.log("QueryData deployed at:", address(quoter));
        
        console2.log("Initializing QueryData...");
        quoter.initialize();
        console2.log("QueryData initialized successfully");
        
        console2.log("=================================");
        console2.log("Deployment Summary:");
        console2.log("QueryData address:", address(quoter));
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("=================================");
        
        vm.stopBroadcast();
    }
}

