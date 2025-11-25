// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    QueryCurveUpgradeable,
    ICurveV2Pool,
    ICurvePool,
    ICurveNGPool,
    TokenInfo,
    IERC20
} from "./QueryCurveUpgradeable.sol";

interface ISpecialRegister {
    function get_balances(address _pool) external view returns (uint256[4] memory);

    function get_coins(address _pool) external view returns (address[4] memory);
}

interface ICurveMetapool {
    function base_pool() external view returns (address);
}

interface ISpecial2Register {
    function get_n_coins(address _pool) external view returns (uint256[2] memory);
}

interface ICurveStableswapFactoryNG {
    function get_balances(address _pool) external view returns (uint256[] memory);

    function get_underlying_balances(address _pool) external view returns (uint256[] memory);

    function get_coins(address _pool) external view returns (address[] memory);

    function get_underlying_coins(address _pool) external view returns (address[] memory);

    function get_underlying_decimals(address _pool) external view returns (uint256[] memory);
}

interface IRegistryHandler {
    function get_balances(address _pool) external view returns (uint256[8] memory);

    function get_underlying_balances(address _pool) external view returns (uint256[8] memory);

    function get_coins(address _pool) external view returns (address[8] memory);

    function get_underlying_coins(address _pool) external view returns (address[8] memory);

    function is_meta(address _pool) external view returns (bool);

    function get_n_coins(address _pool) external view returns (uint256);

    function get_underlying_decimals(address _pool) external view returns (uint256[8] memory);

    function pool_count() external view returns (uint256);

    function pool_list(uint256 i) external view returns (address);

    function get_base_pool(address _pool) external view returns (address);
}

contract CurveMetaRegistryAvalanche {
    address public constant SpecialRegister = 0xb17b674D9c5CB2e441F8e196a2f048A81355d031;
    address public constant Special2Register = 0x8474DdbE98F5aA3179B3B3F5942D724aFcdec9f6;
    address public constant CurveStableswapFactoryNG = 0x1764ee18e8B3ccA4787249Ceb249356192594585;
    address[10] public registerList;

    constructor() {
        registerList[0] = SpecialRegister; // ISpecialRegister
        registerList[1] = Special2Register; // ISpecial2Register
        registerList[2] = CurveStableswapFactoryNG; // ICurveStableswapFactoryNG
    }

    function _get_n_coins(address handler, address pool) internal view returns (uint256 count) {
        if (handler == Special2Register) {
            return ISpecial2Register(handler).get_n_coins(pool)[0];
        }
        return IRegistryHandler(handler).get_n_coins(pool);
    }

    function _get_registry_handlers_from_pool(address pool) internal view returns (address handler) {
        for (uint256 index = 0; index < registerList.length; index++) {
            address register = registerList[index];
            if (register == address(0)) {
                break;
            }
            if (_get_n_coins(register, pool) > 0) {
                return register;
            }
        }
        revert("no registry");
    }

    function pool_count() public view returns (uint256 totalCount) {
        for (uint256 index = 0; index < registerList.length; index++) {
            address register = registerList[index];
            if (register == address(0)) {
                break;
            }
            totalCount += IRegistryHandler(register).pool_count();
        }
    }

    function pool_list(uint256 i) public view returns (address pool) {
        uint256 pools_skip = 0;
        for (uint256 index = 0; index < registerList.length; index++) {
            address register = registerList[index];
            if (register == address(0)) {
                break;
            }
            uint256 count = IRegistryHandler(register).pool_count();
            if (i - pools_skip < count) {
                return IRegistryHandler(register).pool_list(i - pools_skip);
            }
            pools_skip += count;
        }
    }

    function get_balances(address pool) external view returns (uint256[8] memory balances) {
        address register = _get_registry_handlers_from_pool(pool);
        if (register == SpecialRegister) {
            uint256[4] memory _balances = ISpecialRegister(register).get_balances(pool);
            for (uint256 index = 0; index < 4; index++) {
                balances[index] = _balances[index];
            }
        } else if (register == CurveStableswapFactoryNG) {
            uint256[] memory _balances = ICurveStableswapFactoryNG(register).get_balances(pool);
            for (uint256 index = 0; index < _balances.length && index < 8; index++) {
                balances[index] = _balances[index];
            }
        } else {
            return IRegistryHandler(register).get_balances(pool);
        }
    }

    function get_underlying_balances(address pool) external view returns (uint256[8] memory balances) {
        address register = _get_registry_handlers_from_pool(pool);
        if (register == CurveStableswapFactoryNG) {
            uint256[] memory _balances = ICurveStableswapFactoryNG(register).get_underlying_balances(pool);
            for (uint256 index = 0; index < _balances.length && index < 8; index++) {
                balances[index] = _balances[index];
            }
        } else {
            return IRegistryHandler(register).get_underlying_balances(pool);
        }
    }

    function get_coins(address pool) external view returns (address[8] memory coins) {
        address register = _get_registry_handlers_from_pool(pool);
        if (register == SpecialRegister) {
            address[4] memory _coins = ISpecialRegister(register).get_coins(pool);
            for (uint256 index = 0; index < 4; index++) {
                coins[index] = _coins[index];
            }
        } else if (register == CurveStableswapFactoryNG) {
            address[] memory _coins = ICurveStableswapFactoryNG(register).get_coins(pool);
            for (uint256 index = 0; index < _coins.length && index < 8; index++) {
                coins[index] = _coins[index];
            }
        } else {
            return IRegistryHandler(register).get_coins(pool);
        }
    }

    function get_underlying_coins(address pool) external view returns (address[8] memory coins) {
        address register = _get_registry_handlers_from_pool(pool);
        if (register == CurveStableswapFactoryNG) {
            address[] memory _coins = ICurveStableswapFactoryNG(register).get_underlying_coins(pool);
            for (uint256 index = 0; index < _coins.length && index < 8; index++) {
                coins[index] = _coins[index];
            }
        } else {
            return IRegistryHandler(register).get_underlying_coins(pool);
        }
    }

    function is_meta(address pool) external view returns (bool) {
        address register = _get_registry_handlers_from_pool(pool);
        return IRegistryHandler(register).is_meta(pool);
    }

    function get_n_coins(address pool) external view returns (uint256) {
        address register = _get_registry_handlers_from_pool(pool);
        return IRegistryHandler(register).get_n_coins(pool);
    }

    function get_underlying_decimals(address pool) external view returns (uint256[8] memory coins) {
        address register = _get_registry_handlers_from_pool(pool);
        if (register == CurveStableswapFactoryNG) {
            uint256[] memory _coins = ICurveStableswapFactoryNG(register).get_underlying_decimals(pool);
            for (uint256 index = 0; index < _coins.length && index < 8; index++) {
                coins[index] = _coins[index];
            }
        } else {
            return IRegistryHandler(register).get_underlying_decimals(pool);
        }
    }

    function get_base_pool(address pool) external view returns (address basePool) {
        address register = _get_registry_handlers_from_pool(pool);
        if (register == Special2Register) {
            if (IRegistryHandler(register).is_meta(pool)) {
                return ICurveMetapool(pool).base_pool();
            }
        } else {
            return IRegistryHandler(register).get_base_pool(pool);
        }
    }
}

contract QueryCurveUpgradeableAvalanche is UUPSUpgradeable {
    address public address_provider = 0x5ffe7FB82894076ECB99A30D6A32e969e6e35E98;
    address public owner;
    address public meta_registry;

    modifier onlyOwner() {
        require(msg.sender == owner, "Callable only by owner");
        _;
    }

    constructor(address registry) {
        meta_registry = registry;
    }

    function initialize(address _owner) public initializer onlyProxy {
        owner = _owner;
        // Set again here because proxy needs it, otherwise this property in proxy would be 0x0
        address_provider = 0x5ffe7FB82894076ECB99A30D6A32e969e6e35E98;
    }

    function initialize2(address registry) public reinitializer(2) onlyProxy {
        // Set again here because proxy needs it, otherwise this property in proxy would be 0x0
        meta_registry = registry;
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    function meta_register() public view returns (address) {
        return meta_registry;
    }

    function get_balances(address pool) public view returns (uint256[8] memory balances) {
        if (
            pool == 0x7f90122BF0700F9E7e1F688fe926940E8839F353 || pool == 0x16a7DA911A4DD1d83F3fF066fE28F3C792C50d90
                || pool == 0xD2AcAe14ae2ee0f6557aC6C6D0e407a92C36214b
        ) {
            balances = CurveMetaRegistryAvalanche(meta_register()).get_underlying_balances(pool);
            uint256[8] memory decimals = CurveMetaRegistryAvalanche(meta_register()).get_underlying_decimals(pool);
            address[8] memory coins = CurveMetaRegistryAvalanche(meta_register()).get_coins(pool);
            address[8] memory u_coins = CurveMetaRegistryAvalanche(meta_register()).get_underlying_coins(pool);
            uint256 count = CurveMetaRegistryAvalanche(meta_register()).get_n_coins(pool);
            for (uint256 index = 0; index < count; index++) {
                if (coins[index] == u_coins[index]) {
                    balances[index] = balances[index] * (10 ** (18 - decimals[index]));
                }
            }
            return balances;
        }
        return CurveMetaRegistryAvalanche(meta_register()).get_balances(pool);
    }

    function get_tokens(address pool) public view returns (address[8] memory tokens) {
        if (
            pool == 0x7f90122BF0700F9E7e1F688fe926940E8839F353 || pool == 0x16a7DA911A4DD1d83F3fF066fE28F3C792C50d90
                || pool == 0xD2AcAe14ae2ee0f6557aC6C6D0e407a92C36214b
        ) {
            return CurveMetaRegistryAvalanche(meta_register()).get_underlying_coins(pool);
        }
        return CurveMetaRegistryAvalanche(meta_register()).get_coins(pool);
    }

    function get_tokens_with_decimals(address pool) public view returns (TokenInfo[8] memory tokenInfos) {
        address[8] memory tokens;
        if (
            pool == 0x7f90122BF0700F9E7e1F688fe926940E8839F353 || pool == 0x16a7DA911A4DD1d83F3fF066fE28F3C792C50d90
                || pool == 0xD2AcAe14ae2ee0f6557aC6C6D0e407a92C36214b
        ) {
            tokens = CurveMetaRegistryAvalanche(meta_register()).get_underlying_coins(pool);
        } else {
            tokens = CurveMetaRegistryAvalanche(meta_register()).get_coins(pool);
        }

        for (uint256 i = 0; i < 8; i++) {
            if (tokens[i] != address(0)) {
                tokenInfos[i] = TokenInfo({
                    token: tokens[i],
                    decimals: tokens[i] == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE ? 18 : IERC20(tokens[i]).decimals()
                });
            }
        }
    }

    function get_coins(address pool) public view returns (address[8] memory tokens) {
        return CurveMetaRegistryAvalanche(meta_register()).get_coins(pool);
    }

    function get_virtual_price(address pool) public view virtual returns (uint256) {
        try ICurvePool(pool).get_virtual_price() returns (uint256 result1) {
            return result1;
        } catch {
            return 0;
        }
    }

    function get_fee(address pool) public view virtual returns (uint256) {
        try ICurvePool(pool).fee() returns (uint256 result1) {
            return result1;
        } catch {
            return 0;
        }
    }

    function get_params(address pool)
        public
        view
        virtual
        returns (
            int24 name,
            uint256 A,
            uint256 fee,
            uint256 D,
            uint256 gamma,
            uint256 price,
            uint256 fee_gamma,
            uint256 mid_fee,
            uint256 out_fee,
            uint256 liquidity,
            uint256 gas_fee,
            uint256[] memory price_scale
        )
    {
        //params[0] 1-v1  2-v2  3-NG
        name = 1;
        gamma = 0;
        D = 0;
        price = 0;
        fee_gamma = 0;
        mid_fee = 0;
        out_fee = 0;
        liquidity = 0;
        gas_fee = 0;
        uint256 n = CurveMetaRegistryAvalanche(meta_register()).get_n_coins(pool);
        price_scale = new uint256[](n - 1);
        try ICurveV2Pool(pool).gamma() returns (uint256 result0) {
            gamma = result0;
            name = 2;
            D = ICurveV2Pool(pool).D();
            if (n > 2) {
                for (uint256 i = 0; i < n - 1; i++) {
                    price_scale[i] = ICurveV2Pool(pool).price_scale(i);
                }
            } else {
                price_scale[0] = ICurvePool(pool).price_scale();
            }
            fee_gamma = ICurveV2Pool(pool).fee_gamma();
            mid_fee = ICurveV2Pool(pool).mid_fee();
            out_fee = ICurveV2Pool(pool).out_fee();
        } catch {
            price = get_virtual_price(pool);
            try ICurveNGPool(pool).offpeg_fee_multiplier() returns (uint256 result1) {
                gas_fee = result1;
                name = 3;
                if (
                    pool == 0x7f90122BF0700F9E7e1F688fe926940E8839F353
                        || pool == 0x16a7DA911A4DD1d83F3fF066fE28F3C792C50d90
                        || pool == 0xD2AcAe14ae2ee0f6557aC6C6D0e407a92C36214b
                ) {
                    price_scale = new uint256[](n);
                } else {
                    try ICurveNGPool(pool).stored_rates() returns (uint256[] memory result1) {
                        price_scale = result1;
                    } catch {
                        price_scale = new uint256[](n);
                    }
                }
            } catch {
                price_scale = new uint256[](n);
            }
        }
        A = ICurvePool(pool).A();
        fee = get_fee(pool);
    }

    function set_address_provider(address _address_provider) public onlyOwner {
        address_provider = _address_provider;
    }

    function set_owner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function set_meta_registry(address registry) public onlyOwner {
        meta_registry = registry;
    }
}
