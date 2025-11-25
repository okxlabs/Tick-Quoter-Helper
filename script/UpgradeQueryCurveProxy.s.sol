// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/test.sol";
// import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {QueryCurveUpgradeable, QueryCurveUpgradeableV2, TokenInfo} from "../src/Curve/QueryCurveUpgradeable.sol";
import {QueryCurveUpgradeableEth} from "../src/Curve/QueryCurveUpgradeableEth.sol";
// import {QueryCurveUpgradeableOpt} from "../src/Curve/QueryCurveUpgradeableOpt.sol";
// import {QueryCurveUpgradeableArb, CurveMetaRegistryArb} from "../src/Curve/QueryCurveUpgradeableArb.sol";
// import {QueryCurveUpgradeablePolygon, CurveMetaRegistryPolygon, IRegistryHandler} from "../src/Curve/QueryCurveUpgradeablePolygon.sol";
// import {CurveMetaRegistryAvalanche, QueryCurveUpgradeableAvalanche} from "../src/Curve/QueryCurveUpgradeableAvalanche.sol";
import "forge-std/console2.sol";

interface ICurveMetaRegister {
    function pool_count() external view returns (uint256);
    function pool_list(uint256 _index) external view returns (address);
}

// contract UpgradeQueryCurveProxy is Script {
//     address internal constant proxy = 0x5B1cDde612852EC8eA070de3c29CF0c9f0E6700B;

//     function upgrade(address newImpl, bytes memory data) public {
//         vm.broadcast();
//         QueryCurveUpgradeable(proxy).upgradeToAndCall(newImpl, data);
//         console.log("upgradeToAndCall suc");

//         address _owner = QueryCurveUpgradeable(proxy).owner();
//         console.log("get owner:", _owner);
//         assert(_owner == 0x591342772bBc7D0630EFBdeA3C0b704E7ADdad17);
//         address provider = QueryCurveUpgradeable(proxy).address_provider();
//         console.log("get address_provider:", provider);
//         address register = QueryCurveUpgradeable(proxy).meta_register();
//         console.log("meta_register:", register);
//         address pool = ICurveMetaRegister(register).pool_list(0);
//         uint256[8] memory balances = QueryCurveUpgradeable(proxy).get_balances(pool);
//         console.log("get_balances from pool:", pool, balances[0]);
//     }

//     function upgrade(address newImpl) public {
//         bytes memory data;
//         upgrade(newImpl, data);
//     }
// }


// forge script script/UpgradeQueryCurveProxy.s.sol:UpgradeQueryCurveProxyEth  --rpc-url $ETHEREUM_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 1 --etherscan-api-key $ETHERSCAN_API_KEY_ETH --via-ir --verify --broadcast
// forge script script/UpgradeQueryCurveProxy.s.sol:Deploy -vvvv
contract Deploy is Test {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    address internal constant proxy = 0x5B1cDde612852EC8eA070de3c29CF0c9f0E6700B;
    // address internal constant proxy = 0xC3214Bbad3F6f4F240C78c210e581F8C6bcdCeaC;

    function run() public {
        require(deployer == 0x591342772bBc7D0630EFBdeA3C0b704E7ADdad17, "wrong deployer! change the private key");
        // require(deployer == 0x471860c57728A41dBC3123105EFeBc39F3Acfdd8, "wrong deployer! change the private key");
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        vm.startBroadcast(deployer);
        console2.log("block.chainID", block.chainid);
        require(block.chainid == 1, "must be eth");

        // address newImpl = 0x6E2f48FEa07be609e40eD3dA8105407aD3751BBa;

        QueryCurveUpgradeable newImpl = new QueryCurveUpgradeableEth();
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
        uint256[8] memory balances = QueryCurveUpgradeable(proxy).get_balances(pool);
        console.log("get_balances from pool:", pool, balances[0]);

        vm.stopBroadcast();
    }
}

// // forge script script/UpgradeQueryCurveProxy.s.sol:UpgradeQueryCurveProxyOpt  --rpc-url $optimism_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 10 --etherscan-api-key $ETHERSCAN_API_KEY_OP --via-ir --verify --broadcast
// contract UpgradeQueryCurveProxyOpt is UpgradeQueryCurveProxy {
//     function setUp() public {}

//     function run() public {
//         vm.broadcast();
//         QueryCurveUpgradeable newImpl = new QueryCurveUpgradeableOpt();
//         console2.log("New impl contract deployed at:", address(newImpl));
//         upgrade(address(newImpl));
//         uint256[8] memory balances = QueryCurveUpgradeable(proxy).get_balances(0x66B5792ED50a2a7405Ea75C4B6B1913eF4E46661);
//         console.log("get_balances:", balances[0], balances[1], balances[2]);
//         TokenInfo[8] memory tokens = QueryCurveUpgradeable(proxy).get_tokens_with_decimals(0x66B5792ED50a2a7405Ea75C4B6B1913eF4E46661);
//         console.log("get_tokens:", tokens[0].token, tokens[1].token, tokens[2].token);
//         console.log("get_decimals:", tokens[0].decimals, tokens[1].decimals, tokens[2].decimals);
//         (, , , , , , , , , , , uint256[] memory price_scale) = QueryCurveUpgradeable(proxy).get_params(0x66B5792ED50a2a7405Ea75C4B6B1913eF4E46661);
//         console.log("price_scale:", price_scale[0], price_scale[1]);
//         (, , , , , , , , , , , uint256[] memory price_scale2) = QueryCurveUpgradeable(proxy).get_params(0xB90B9B1F91a01Ea22A182CD84C1E22222e39B415);
//         console.log("price_scale:", price_scale2[0], price_scale2[1]);
//     }
// }

// // forge script script/UpgradeQueryCurveProxy.s.sol:UpgradeQueryCurveProxyArb  --rpc-url $arb_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 42161 --etherscan-api-key $ETHERSCAN_API_KEY_ARB --via-ir --verify --broadcast
// contract UpgradeQueryCurveProxyArb is UpgradeQueryCurveProxy {
//     function setUp() public {}

//     function run() public {
//         vm.broadcast();
//         QueryCurveUpgradeable newImpl = new QueryCurveUpgradeableArb();
//         console2.log("New impl contract deployed at:", address(newImpl));
//         upgrade(address(newImpl));
//         (, , , , , , , , , , , uint256[] memory price_scale) = QueryCurveUpgradeable(proxy).get_params(0x6eB2dc694eB516B16Dc9FBc678C60052BbdD7d80);
//         console.log("price_scale:", price_scale[0], price_scale[1]);
//         (, , , , , , , , , , , uint256[] memory price_scale2) = QueryCurveUpgradeable(proxy).get_params(0x2AB1ABc1b35c48Aa29549cEB5430712Df105D46c);
//         console.log("price_scale:", price_scale2[0], price_scale2[1]);
//     }

// }

// // forge script script/UpgradeQueryCurveProxy.s.sol:QueryCurveUpgradeableProxyPolygon  --rpc-url $polygon_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 137 --etherscan-api-key $ETHERSCAN_API_KEY_polygon --via-ir --verify --broadcast
// contract QueryCurveUpgradeableProxyPolygon is UpgradeQueryCurveProxy {
//     function setUp() public {}

//     function run() public {
//         vm.broadcast();
//         QueryCurveUpgradeable newImpl = new QueryCurveUpgradeablePolygon();
//         console2.log("New impl contract deployed at:", address(newImpl));
//         upgrade(address(newImpl));
//         uint256[8] memory balances = QueryCurveUpgradeable(proxy).get_balances(0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67);
//         console.log("get_balances:", balances[0], balances[1]);
//         uint256[8] memory balances2 = QueryCurveUpgradeable(proxy).get_balances(0x445FE580eF8d70FF569aB36e80c647af338db351);
//         console.log("get_balances:", balances2[0], balances2[1], balances2[2]);
//         TokenInfo[8] memory tokens = QueryCurveUpgradeablePolygon(proxy).get_tokens_with_decimals(0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67);
//         console.log("get_tokens:", tokens[0].token, tokens[1].token);
//         console.log("get_decimals:", tokens[0].decimals, tokens[1].decimals);
//         TokenInfo[8] memory tokens2 = QueryCurveUpgradeablePolygon(proxy).get_tokens_with_decimals(0x445FE580eF8d70FF569aB36e80c647af338db351);
//         console.log("get_tokens2:", tokens2[0].token, tokens2[1].token, tokens2[2].token);
//         console.log("get_decimals2:", tokens2[0].decimals, tokens2[1].decimals, tokens2[2].decimals);
//         (, , , , , , , , , , , uint256[] memory price_scale) = QueryCurveUpgradeable(proxy).get_params(0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67);
//         console.log("price_scale:", price_scale[0], price_scale[1]);
//         (, , , , , , , , , , , uint256[] memory price_scale2) = QueryCurveUpgradeable(proxy).get_params(0x445FE580eF8d70FF569aB36e80c647af338db351);
//         console.log("price_scale:", price_scale2[0], price_scale2[1], price_scale2[2]);
//     }
// }

// // forge script script/UpgradeQueryCurveProxy.s.sol:QueryCurveUpgradeableProxyAvalanche  --rpc-url $avalanche_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 43114 --etherscan-api-key $ETHERSCAN_API_KEY_avalanche --via-ir --verify --broadcast
// contract QueryCurveUpgradeableProxyAvalanche is UpgradeQueryCurveProxy {
//     address internal registryAddr;

//     function setUp() public {
//         registryAddr = 0x61228cAa4d06247Ca2751cf0f1de0f7d1917aAce;
//     }

//     function run() public {
//         if (registryAddr == address(0)) {
//             vm.broadcast();
//             CurveMetaRegistryAvalanche registry = new CurveMetaRegistryAvalanche();
//             registryAddr = address(registry);
//             console2.log("New CurveMetaRegistryAvalanche deployed at:", registryAddr);
//         }
//         vm.broadcast();
//         QueryCurveUpgradeableAvalanche newImpl = new QueryCurveUpgradeableAvalanche(registryAddr);
//         console2.log("New impl contract deployed at:", address(newImpl));
//         // bytes memory data = abi.encodeWithSignature("initialize2(address)", registryAddr);
//         // upgrade(address(newImpl), data);
//         // upgrade(0xDbc246aaDD1293Cb3314F15E606CDE8c7c6121AE);
//         upgrade(address(newImpl));
//         if (QueryCurveUpgradeableAvalanche(proxy).meta_registry() != registryAddr) {
//             vm.broadcast();
//             QueryCurveUpgradeableAvalanche(proxy).set_meta_registry(registryAddr);
//         }
//     }
// }

// // forge script script/UpgradeQueryCurveProxy.s.sol:UpgradeQueryCurveProxyBase  --rpc-url $base_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 8453 --etherscan-api-key $ETHERSCAN_API_KEY_BASE --via-ir --verify --broadcast
// contract UpgradeQueryCurveProxyBase is UpgradeQueryCurveProxy {
//     function setUp() public {}

//     function run() public {
//         vm.broadcast();
//         QueryCurveUpgradeable newImpl = new QueryCurveUpgradeableV2();
//         console2.log("New impl contract deployed to base chain:", address(newImpl));
//         upgrade(address(newImpl));
//     }

// }


// // forge script script/UpgradeQueryCurveProxy.s.sol:UpgradeCurveMetaRegistryAvalanche  --rpc-url $avalanche_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --via-ir
// contract UpgradeCurveMetaRegistryAvalanche is UpgradeQueryCurveProxy {
//     function setUp() public {}

//     function run() public {
//         vm.broadcast();
//         CurveMetaRegistryAvalanche registry = new CurveMetaRegistryAvalanche();
//         console2.log("New CurveMetaRegistryAvalanche deployed at:", address(registry));
//         vm.broadcast();
//         QueryCurveUpgradeableAvalanche(proxy).set_meta_registry(address(registry));
//     }
// }

// // forge script script/UpgradeQueryCurveProxy.s.sol:UpgradeCurveMetaRegistryPolygon  --rpc-url $polygon_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 137 --etherscan-api-key $ETHERSCAN_API_KEY_polygon --via-ir --verify --broadcast
// contract UpgradeCurveMetaRegistryPolygon is Script {
//     address internal constant proxy = 0x5B1cDde612852EC8eA070de3c29CF0c9f0E6700B;

//     function setUp() public {}

//     function run() public {
//         vm.broadcast();
//         CurveMetaRegistryPolygon newImpl = new CurveMetaRegistryPolygon();
//         console2.log("New impl contract deployed at:", address(newImpl));
//         assert(newImpl.get_address(0) == address(newImpl));
//         assert(newImpl.get_base_pool(0x9b3d675FDbe6a0935E8B7d1941bc6f78253549B7) == address(0));
//         assert(IRegistryHandler(address(newImpl)).pool_list(1) == 0x445FE580eF8d70FF569aB36e80c647af338db351);

//         vm.broadcast();
//         QueryCurveUpgradeablePolygon(proxy).set_address_provider(address(newImpl));
//         assert(QueryCurveUpgradeablePolygon(proxy).meta_register() == address(newImpl));
//         uint256[8] memory balances = QueryCurveUpgradeable(proxy).get_balances(0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67);
//         console.log("get_balances:", balances[0], balances[1]);
//         uint256[8] memory balances2 = QueryCurveUpgradeable(proxy).get_balances(0x445FE580eF8d70FF569aB36e80c647af338db351);
//         console.log("get_balances:", balances2[0], balances2[1], balances2[2]);
//         TokenInfo[8] memory tokens = QueryCurveUpgradeablePolygon(proxy).get_tokens_with_decimals(0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67);
//         console.log("get_tokens:", tokens[0].token, tokens[1].token);
//         console.log("get_decimals:", tokens[0].decimals, tokens[1].decimals);
//         TokenInfo[8] memory tokens2 = QueryCurveUpgradeablePolygon(proxy).get_tokens_with_decimals(0x445FE580eF8d70FF569aB36e80c647af338db351);
//         console.log("get_tokens:", tokens2[0].token, tokens2[1].token, tokens2[2].token);
//         console.log("get_decimals:", tokens2[0].decimals, tokens2[1].decimals, tokens2[2].decimals);
//         (, , , , , , , , , , , uint256[] memory price_scale) = QueryCurveUpgradeable(proxy).get_params(0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67);
//         console.log("price_scale:", price_scale[0], price_scale[1]);
//         (, , , , , , , , , , , uint256[] memory price_scale2) = QueryCurveUpgradeable(proxy).get_params(0x445FE580eF8d70FF569aB36e80c647af338db351);
//         console.log("price_scale:", price_scale2[0], price_scale2[1], price_scale2[2]);
//     }
// }

// // forge script script/UpgradeQueryCurveProxy.s.sol:UpgradeCurveMetaRegistryArb  --rpc-url $arb_RPC_URL --password $KEYSTORE_PAS --sender $DEPLOY_SENDER --chain-id 42161 --etherscan-api-key $ETHERSCAN_API_KEY_ARB --via-ir --verify --broadcast
// contract UpgradeCurveMetaRegistryArb is Script {
//     address internal constant proxy = 0x5B1cDde612852EC8eA070de3c29CF0c9f0E6700B;

//     function setUp() public {}

//     function run() public {
//         vm.broadcast();
//         CurveMetaRegistryArb newImpl = new CurveMetaRegistryArb();
//         console2.log("New impl contract deployed at:", address(newImpl));
//         assert(newImpl.get_address(0) == address(newImpl));
//         assert(newImpl.get_base_pool(0x960ea3e3C7FB317332d990873d354E18d7645590) == address(0));
//         assert(IRegistryHandler(address(newImpl)).pool_list(1) == 0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb);

//         vm.broadcast();
//         QueryCurveUpgradeableArb(proxy).set_address_provider(address(newImpl));
//         assert(QueryCurveUpgradeableArb(proxy).meta_register() == address(newImpl));
//     }
// }