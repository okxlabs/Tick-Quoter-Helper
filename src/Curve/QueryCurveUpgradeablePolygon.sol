// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {
    QueryCurveUpgradeableV2,
    ICurveMetaRegister,
    ICurveV2Pool,
    ICurvePool,
    ICurveNGPool,
    IAddressProvider,
    TokenInfo,
    IERC20
} from "./QueryCurveUpgradeable.sol";

interface IRegistryHandler {
    function pool_count() external view returns (uint256);

    function pool_list(uint256 i) external view returns (address);

    function get_base_pool(address _pool) external view returns (address);
}

contract CurveMetaRegistryPolygon {
    fallback() external virtual {
        address implementation = _get_implementation();
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := call(gas(), implementation, 0, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // call returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _get_implementation() internal view returns (address) {
        return IAddressProvider(0x5ffe7FB82894076ECB99A30D6A32e969e6e35E98).get_address(7);
    }

    function get_base_pool(address pool) external view returns (address basePool) {
        try IRegistryHandler(_get_implementation()).get_base_pool(pool) returns (address _basePool) {
            return _basePool;
        } catch {}
    }

    function get_address(uint256 /* _id */ ) external view returns (address) {
        return address(this);
    }
}

contract QueryCurveUpgradeablePolygon is QueryCurveUpgradeableV2 {
    function get_balances(address pool) public view override returns (uint256[8] memory balances) {
        if (pool == 0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67) {
            balances = ICurveMetaRegister(meta_register()).get_underlying_balances(pool);
            balances[0] *= 10 ** 10;
            // balances[1] *= 10**10;
            return balances;
        }
        if (pool == 0x445FE580eF8d70FF569aB36e80c647af338db351) {
            balances = ICurveMetaRegister(meta_register()).get_underlying_balances(pool);
            balances[1] *= 10 ** 12;
            balances[2] *= 10 ** 12;
            return balances;
        }
        return ICurveMetaRegister(meta_register()).get_balances(pool);
    }

    function get_tokens(address pool) public view override returns (address[8] memory tokens) {
        if (pool == 0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67 || pool == 0x445FE580eF8d70FF569aB36e80c647af338db351) {
            return ICurveMetaRegister(meta_register()).get_underlying_coins(pool);
        }
        return ICurveMetaRegister(meta_register()).get_coins(pool);
    }

    function get_tokens_with_decimals(address pool) public view override returns (TokenInfo[8] memory tokenInfos) {
        address[8] memory tokens;
        if (pool == 0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67 || pool == 0x445FE580eF8d70FF569aB36e80c647af338db351) {
            tokens = ICurveMetaRegister(meta_register()).get_underlying_coins(pool);
        } else {
            tokens = ICurveMetaRegister(meta_register()).get_coins(pool);
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

    function get_params(address pool)
        public
        view
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
                if (
                    pool == 0xC2d95EEF97Ec6C17551d45e77B590dc1F9117C67
                        || pool == 0x445FE580eF8d70FF569aB36e80c647af338db351
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
}
