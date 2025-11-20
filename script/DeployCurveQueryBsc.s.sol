// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {QueryCurveUpgradeableBsc} from "../src/Curve/QueryCurveUpgradeableBsc.sol";

contract DeployCurveQueryBsc is Script {
    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address owner = vm.envOr("CURVE_QUERY_OWNER_BSC", vm.envOr("CURVE_QUERY_OWNER", deployer));

        // vm.createSelectFork(vm.envString("BSC_RPC_URL"));

        vm.startBroadcast(deployer);
        require(block.chainid == 56, "Deploy on BSC");

        QueryCurveUpgradeableBsc implementation = new QueryCurveUpgradeableBsc();
        bytes memory initData = abi.encodeCall(QueryCurveUpgradeableBsc.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console2.log("BSC QueryCurve implementation", address(implementation));
        console2.log("BSC QueryCurve proxy", address(proxy));
        console2.log("BSC QueryCurve owner", QueryCurveUpgradeableBsc(address(proxy)).owner());

        vm.stopBroadcast();
    }
}

