// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/test.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    QueryCurveUpgradeable,
    QueryCurveUpgradeableV2,
    TokenInfo
} from "../src/Curve/QueryCurveUpgradeable.sol";
import {
    QueryCurveUpgradeableBase
} from "../src/Curve/QueryCurveUpgradeableBase.sol";
import "forge-std/console2.sol";

interface ICurveMetaRegister {
    function pool_count() external view returns (uint256);
    function pool_list(uint256 _index) external view returns (address);
}

contract Deploy is Test {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    address internal constant proxy =
        0x5B1cDde612852EC8eA070de3c29CF0c9f0E6700B;

    function run() public {
        require(
            deployer == 0x591342772bBc7D0630EFBdeA3C0b704E7ADdad17,
            "wrong deployer! change the private key"
        );
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        vm.startBroadcast(deployer);
        console2.log("block.chainID", block.chainid);
        require(block.chainid == 1, "must be eth");

        // address newImpl = 0x6E2f48FEa07be609e40eD3dA8105407aD3751BBa;

        QueryCurveUpgradeableBase newImpl = new QueryCurveUpgradeableBase();
        console2.log("New impl contract deployed at:", address(newImpl));

        // QueryCurveUpgradeable(proxy).initialize(deployer);
        bytes memory data;
        QueryCurveUpgradeable(proxy).upgradeToAndCall(address(newImpl), data);
        console.log("upgradeToAndCall suc");

        address _owner = QueryCurveUpgradeable(proxy).owner();
        console.log("get owner:", _owner);
        assert(_owner == 0x591342772bBc7D0630EFBdeA3C0b704E7ADdad17);
        address provider = QueryCurveUpgradeable(proxy).address_provider();
        console.log("get address_provider:", provider);
        address register = QueryCurveUpgradeable(proxy).meta_register();
        console.log("meta_register:", register);
        address pool = ICurveMetaRegister(register).pool_list(0);
        uint256[8] memory balances = QueryCurveUpgradeable(proxy).get_balances(
            pool
        );
        console.log("get_balances from pool:", pool, balances[0]);

        vm.stopBroadcast();
    }
}
