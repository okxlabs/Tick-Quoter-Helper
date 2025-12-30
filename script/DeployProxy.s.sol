// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts-v4_5/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts-v4_5/proxy/transparent/ProxyAdmin.sol";

contract DeployProxy is Script {
    function run() public returns (address proxyAdmin, address proxy) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address implementation = vm.envAddress("IMPLEMENTATION");

        console2.log("=== Deploying Proxy ===");
        console2.log("Deployer:", deployer);
        console2.log("Implementation:", implementation);
        console2.log("Chain ID:", block.chainid);
        require(implementation != address(0), "IMPLEMENTATION env var not set");

        vm.startBroadcast(deployerKey);

        // Deploy ProxyAdmin
        console2.log("[1/2] Deploying ProxyAdmin...");
        ProxyAdmin admin = new ProxyAdmin();
        proxyAdmin = address(admin);
        console2.log("  ProxyAdmin:", proxyAdmin);

        // Deploy TransparentUpgradeableProxy with initialize()
        console2.log("[2/2] Deploying TransparentUpgradeableProxy...");
        bytes memory initData = abi.encodeWithSignature("initialize()");
        TransparentUpgradeableProxy transparentProxy = new TransparentUpgradeableProxy(
            implementation,
            proxyAdmin,
            initData
        );
        proxy = address(transparentProxy);

        vm.stopBroadcast();

        console2.log("=========================================");
        console2.log("  PROXY DEPLOYMENT SUCCESS!");
        console2.log("=========================================");
        console2.log("Proxy:", proxy);
        console2.log("ProxyAdmin:", proxyAdmin);
        console2.log("Implementation:", implementation);
        console2.log("=========================================");

        return (proxyAdmin, proxy);
    }
}
