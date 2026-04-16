// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Script.sol";
// import "forge-std/console2.sol";
// import {ProxyAdmin} from "../lib/openzeppelin-contracts-v4_5/contracts/proxy/transparent/ProxyAdmin.sol";
// import {TransparentUpgradeableProxy} from "../lib/openzeppelin-contracts-v4_5/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// contract UpgradeProxy is Script {
//     function run() public {
//         uint256 deployerKey = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.addr(deployerKey);

//         address proxy = __PROXY__;
//         address proxyAdminAddr = __PROXY_ADMIN__;
//         address newImplementation = __NEW_IMPLEMENTATION__;

//         // Chain safety check — replaced by prepare_upgrade.js
//         require(block.chainid == __CHAIN_ID__, "Chain ID mismatch!");

//         console2.log("=========================================");
//         console2.log("        Upgrading Proxy          ");
//         console2.log("=========================================");
//         console2.log("Deployer:", deployer);
//         console2.log("Chain ID:", block.chainid);
//         console2.log("Proxy Address:", proxy);
//         console2.log("ProxyAdmin Address:", proxyAdminAddr);
//         console2.log("New Implementation:", newImplementation);

//         ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);

//         address currentImplementation =
//             proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(proxy)));
//         console2.log("Current Implementation:", currentImplementation);

//         address owner = proxyAdmin.owner();
//         console2.log("ProxyAdmin Owner:", owner);
//         require(deployer == owner, "Deployer is not ProxyAdmin owner!");
//         require(newImplementation != currentImplementation, "Same implementation!");

//         vm.startBroadcast(deployerKey);
//         console2.log("Executing upgrade...");
//         proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(proxy)), newImplementation);
//         vm.stopBroadcast();

//         address updatedImplementation =
//             proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(proxy)));

//         console2.log("");
//         console2.log("=========================================");
//         console2.log("          UPGRADE SUCCESSFUL!            ");
//         console2.log("=========================================");
//         console2.log("Proxy Address:", proxy);
//         console2.log("Old Implementation:", currentImplementation);
//         console2.log("New Implementation:", updatedImplementation);
//         console2.log("");

//         require(updatedImplementation == newImplementation, "Upgrade verification failed!");
//     }
// }
