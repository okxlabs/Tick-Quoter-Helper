// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {ProxyAdmin} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeProxy is Script {
    // REPLACED BY scripts/replace.js
    // We store 21-byte hex literals (0x00 + 20-byte address) to avoid checksum enforcement,
    // then truncate back to 20 bytes via uint160(...).
    address internal constant PROXY = address(uint160(0x00cc4739736420c1d6f3f5dbb53cd52e4ac0d06c9a));
    address internal constant PROXY_ADMIN = address(uint160(0x00b18792ba1dbd677eb300660304e9e71e372da421));
    address internal constant NEW_IMPLEMENTATION = address(uint160(0x00479b3862531135e4d4b9466ebdcfe4974ff16f94));
    // Old Implementation: 0x643C607219513AaEdC96b78b152c71E3DB976ac7

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        require(block.chainid == 1, "Must be the right chain");

        console2.log("=========================================");
        console2.log("        Upgrading Proxy          ");
        console2.log("=========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("Proxy Address:", PROXY);
        console2.log("ProxyAdmin Address:", PROXY_ADMIN);
        console2.log("New Implementation:", NEW_IMPLEMENTATION);

        ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);

        address currentImplementation =
            proxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(PROXY)));
        console2.log("Current Implementation:", currentImplementation);

        address owner = proxyAdmin.owner();
        console2.log("ProxyAdmin Owner:", owner);
        require(deployer == owner, "Deployer is not ProxyAdmin owner!");
        require(NEW_IMPLEMENTATION != currentImplementation, "Same implementation!");

        vm.startBroadcast(deployerKey);
        console2.log("Executing upgrade...");
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(payable(PROXY)), NEW_IMPLEMENTATION);
        vm.stopBroadcast();

        address updatedImplementation =
            proxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(PROXY)));

        console2.log("");
        console2.log("=========================================");
        console2.log("          UPGRADE SUCCESSFUL!            ");
        console2.log("=========================================");
        console2.log("Proxy Address:", PROXY);
        console2.log("Old Implementation:", currentImplementation);
        console2.log("New Implementation:", updatedImplementation);
        console2.log("");

        require(updatedImplementation == NEW_IMPLEMENTATION, "Upgrade verification failed!");
    }
}


