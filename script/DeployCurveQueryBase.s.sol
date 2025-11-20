// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/Curve/QueryCurveUpgradeableBase.sol";

contract DeployCurveQueryBase is Script {
    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address owner = vm.envOr("CURVE_QUERY_OWNER_BASE", vm.envOr("CURVE_QUERY_OWNER", deployer));

        // vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        vm.startBroadcast(deployer);
        require(block.chainid == 8453, "Deploy on Base");

        QueryCurveUpgradeableBase implementation = new QueryCurveUpgradeableBase();
        bytes memory initData = abi.encodeCall(QueryCurveUpgradeableBase.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console2.log("Base QueryCurve implementation", address(implementation));
        console2.log("Base QueryCurve proxy", address(proxy));
        console2.log("Base QueryCurve owner", QueryCurveUpgradeableBase(address(proxy)).owner());

        vm.stopBroadcast();
    }
}

