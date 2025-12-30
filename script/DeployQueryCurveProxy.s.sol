// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {QueryCurveUpgradeable} from "../src/Curve/QueryCurveUpgradeable.sol";
import "forge-std/console2.sol";

interface IImmutableCreate2Factory {
    function safeCreate2(bytes32 salt, bytes calldata initializationCode) external payable returns (address deploymentAddress);
}

interface ICurveMetaRegister {
    function pool_count() external view returns (uint256);
    function pool_list(uint256 _index) external view returns (address);
}

contract DeployQueryCurveUpgradeable is Script {
    address internal constant deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address internal constant deployer2 = 0x0000000000FFe8B47B3e2130213B802212439497;

    function setUp() public virtual {}

    function deploy(bytes32 salt, bytes memory payload) public returns (address) {
        vm.broadcast();
        (bool success, bytes memory result) = deployer.call{value: 0}(abi.encodePacked(salt, payload));
        require(success, "Deployment failed");
        // console2.logBytes(result);
        // console2.log(result.length);

        address newContractAddress;
        assembly {
            newContractAddress := mload(add(result, 20))
        }

        console2.log("New contract deployed at:", newContractAddress);
        return newContractAddress;
    }

    function deploy2(bytes32 salt, bytes memory payload) public returns (address) {
        vm.broadcast();
        salt = 0;
        address newContractAddress = IImmutableCreate2Factory(deployer2).safeCreate2(salt, payload);
        console2.log("New contract deployed at:", newContractAddress);
        return newContractAddress;
    }

    function deployQueryCurveUpgradeable() public returns (address) {
        console.log("start deply QueryCurveUpgradeable:");
        bytes memory bytecode = type(QueryCurveUpgradeable).creationCode;
        bytes32 salt = keccak256(abi.encodePacked("QueryCurveUpgradeable"));
        address newContractAddress = deploy(salt, bytecode);
        assert(newContractAddress == 0x2109B30D287C729866618Adac995602168C2C118);

        address register = QueryCurveUpgradeable(newContractAddress).meta_register();
        console.log("meta_register:", register);
        address pool = ICurveMetaRegister(register).pool_list(0);
        uint256[8] memory balances = QueryCurveUpgradeable(newContractAddress).get_balances(pool);
        console.log("get_balances from pool:", pool, balances[0]);
        return newContractAddress;
    }

    function run() public virtual {
        deployQueryCurveUpgradeable();
    }
}

contract DeployQueryCurveProxy is DeployQueryCurveUpgradeable {
    address internal constant implementation = 0x2109B30D287C729866618Adac995602168C2C118;
    address internal constant owner = 0x86e024B18d575d5c11756048B3918FD478dEE5e9;

    function setUp() public override {}

    function run() public override {
        if (implementation.code.length == 0) {
            address newImplementaion = deployQueryCurveUpgradeable();
            assert(implementation == newImplementaion);
        }
        console.log("start deply ERC1967Proxy:");
        bytes memory bytecode = type(ERC1967Proxy).creationCode;
        bytes memory _data = abi.encodeWithSignature("initialize(address)", owner);
        bytes memory constructorArgs = abi.encode(implementation, _data);
        bytes memory payload = abi.encodePacked(bytecode, constructorArgs);
        bytes32 salt = keccak256(abi.encodePacked("QueryCurveERC1967Proxy"));
        address newContractAddress = deploy(salt, payload); 
        assert(newContractAddress == 0x5B1cDde612852EC8eA070de3c29CF0c9f0E6700B);

        address _owner = QueryCurveUpgradeable(newContractAddress).owner();
        console.log("get owner:", _owner);
        address provider = QueryCurveUpgradeable(newContractAddress).address_provider();
        console.log("get address_provider:", provider);
        address register = QueryCurveUpgradeable(newContractAddress).meta_register();
        console.log("meta_register:", register);
        address pool = ICurveMetaRegister(register).pool_list(0);
        uint256[8] memory balances = QueryCurveUpgradeable(newContractAddress).get_balances(pool);
        console.log("get_balances from pool:", pool, balances[0]);
    }
}