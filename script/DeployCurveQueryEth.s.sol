// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/Curve/QueryCurveUpgradeableEth.sol";

contract DeployCurveQueryEth is Script {
    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address owner = vm.envOr("CURVE_QUERY_OWNER_ETH", vm.envOr("CURVE_QUERY_OWNER", deployer));

        // vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        vm.startBroadcast(deployer);
        require(block.chainid == 1, "Deploy on Ethereum mainnet");

        QueryCurveUpgradeableEth implementation = new QueryCurveUpgradeableEth();
        bytes memory initData = abi.encodeCall(QueryCurveUpgradeableEth.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console2.log("Ethereum QueryCurve implementation", address(implementation));
        console2.log("Ethereum QueryCurve proxy", address(proxy));
        console2.log("Ethereum QueryCurve owner", QueryCurveUpgradeableEth(address(proxy)).owner());

        vm.stopBroadcast();
    }
}

