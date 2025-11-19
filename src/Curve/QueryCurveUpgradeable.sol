// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface ICurveMetaRegister {
    function get_balances(address _pool) external view returns (uint256[8] memory);

    function get_underlying_balances(address _pool) external view returns (uint256[8] memory);

    function get_coins(address _pool) external view returns (address[8] memory);

    function get_underlying_coins(address _pool) external view returns (address[8] memory);

    function is_meta(address _pool) external view returns (bool);

    function get_n_coins(address _pool) external view returns (uint256);

    function get_registry_handlers_from_pool(address _pool) external view returns (address[10] memory);
}

interface ICurveV2Pool {
    function gamma() external view returns (uint256);

    function D() external view returns (uint256);

    function price_scale(uint256 k) external view returns (uint256);

    function fee_gamma() external view returns (uint256);

    function mid_fee() external view returns (uint256);

    function out_fee() external view returns (uint256);

    function last_prices_timestamp() external view returns (uint256);
}

interface ICurveNGPool {
    function offpeg_fee_multiplier() external view returns (uint256);

    function stored_rates() external view returns (uint256[] memory);
}

interface ICurvePool {
    function A() external view returns (uint256);

    function fee() external view returns (uint256);

    function price_scale() external view returns (uint256);

    function get_virtual_price() external view returns (uint256);
}

interface IAddressProvider {
    function get_address(uint256 _id) external view returns (address);
}

interface IERC20 {
    function decimals() external view returns (uint8);
}

struct TokenInfo {
    address token;
    uint8 decimals;
}

contract QueryCurveUpgradeable is UUPSUpgradeable {
    address public address_provider = 0x5ffe7FB82894076ECB99A30D6A32e969e6e35E98;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Callable only by owner");
        _;
    }

    function initialize(address _owner) public initializer onlyProxy {
        owner = _owner;
        // Set again here because proxy needs it, otherwise this property in proxy would be 0x0
        address_provider = 0x5ffe7FB82894076ECB99A30D6A32e969e6e35E98;
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    function meta_register() public view returns (address) {
        return IAddressProvider(address_provider).get_address(7);
    }

    function get_balances(address pool) public view virtual returns (uint256[8] memory balances) {
        return ICurveMetaRegister(meta_register()).get_balances(pool);
    }

    function get_tokens(address pool) public view virtual returns (address[8] memory tokens) {
        return ICurveMetaRegister(meta_register()).get_coins(pool);
    }

    function get_tokens_with_decimals(address pool) public view virtual returns (TokenInfo[8] memory tokenInfos) {
        address[8] memory tokens;
        tokens = ICurveMetaRegister(meta_register()).get_coins(pool);

        for (uint256 i = 0; i < 8; i++) {
            if (tokens[i] != address(0)) {
                tokenInfos[i] = TokenInfo({
                    token: tokens[i],
                    decimals: tokens[i] == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE ? 18 : IERC20(tokens[i]).decimals()
                });
            }
        }
    }

    function get_coins(address pool) public view virtual returns (address[8] memory tokens) {
        return ICurveMetaRegister(meta_register()).get_coins(pool);
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
        uint256 n = ICurveMetaRegister(meta_register()).get_n_coins(pool);
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
            price = ICurvePool(pool).get_virtual_price();
            try ICurveNGPool(pool).offpeg_fee_multiplier() returns (uint256 result1) {
                gas_fee = result1;
                name = 3;
                price_scale = ICurveNGPool(pool).stored_rates();
            } catch {
                price_scale = new uint256[](n);
            }
        }
        A = ICurvePool(pool).A();
        fee = ICurvePool(pool).fee();
    }

    function set_address_provider(address _address_provider) public onlyOwner {
        address_provider = _address_provider;
    }

    function set_owner(address _owner) public onlyOwner {
        owner = _owner;
    }
}

contract QueryCurveUpgradeableV2 is QueryCurveUpgradeable {
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
        override
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
        uint256 n = ICurveMetaRegister(meta_register()).get_n_coins(pool);
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
                try ICurveNGPool(pool).stored_rates() returns (uint256[] memory result1) {
                    price_scale = result1;
                } catch {
                    price_scale = new uint256[](n);
                }
            } catch {
                price_scale = new uint256[](n);
            }
        }
        A = ICurvePool(pool).A();
        fee = get_fee(pool);
    }
}
