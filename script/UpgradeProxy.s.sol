// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {ProxyAdmin} from "../lib/openzeppelin-contracts-v4_5/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "../lib/openzeppelin-contracts-v4_5/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeProxy is Script {
    // REPLACED BY scripts/sync_upgrade_constants.js
    address internal constant PROXY = 0xC0FaB674fF7DdF8B891495bA9975B0Fe1dCaC735;
    address internal constant PROXY_ADMIN = 0xDeEF773D61719a3181E35e9281600Db8bA063f71;
    address internal constant NEW_IMPLEMENTATION = 0xb70FF46899ddEd5CD1018FA446D1E78dC0dD6210;
    // Old Implementation: 0xd22caC235c9D2A8252b0e02985a6C67a959b21b0

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
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(PROXY)));
        console2.log("Current Implementation:", currentImplementation);

        address owner = proxyAdmin.owner();
        console2.log("ProxyAdmin Owner:", owner);
        require(deployer == owner, "Deployer is not ProxyAdmin owner!");
        require(NEW_IMPLEMENTATION != currentImplementation, "Same implementation!");

        vm.startBroadcast(deployerKey);
        console2.log("Executing upgrade...");
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(PROXY)), NEW_IMPLEMENTATION);
        vm.stopBroadcast();

        address updatedImplementation =
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(PROXY)));

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


