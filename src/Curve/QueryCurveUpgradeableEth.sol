// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {
    QueryCurveUpgradeableV2,
    ICurveMetaRegister,
    ICurveV2Pool,
    ICurvePool,
    ICurveNGPool,
    TokenInfo,
    IERC20
} from "./QueryCurveUpgradeable.sol";

interface ICurveMainBaseRegistry {
    function get_underlying_balances(address _pool) external view returns (uint256[8] memory);
    function get_underlying_coins(address _pool) external view returns (address[8] memory);
    function get_coins(address _pool) external view returns (address[8] memory);
}

interface IRai {
    function redemption_price_snap() external view returns (address);

    function snappedRedemptionPrice() external view returns (uint256);
}

interface AETH {
    function ratio() external view returns (uint256);
}

interface RETH {
    function getExchangeRate() external view returns (uint256);
}

interface ICurveSpecialPool {
    function coins(uint256 _index) external view returns (address);
}

interface ICurveMetaPool {
    function base_pool() external view returns (address);
}

interface ICurveNG2Pool {
    function stored_rates() external view returns (uint256[2] memory);
}

contract QueryCurveUpgradeableEth is QueryCurveUpgradeableV2 {
    function get_balances(address pool) public view override returns (uint256[8] memory balances) {
        bool is_meta = ICurveMetaRegister(meta_register()).is_meta(pool);
        address[10] memory handlers = ICurveMetaRegister(meta_register()).get_registry_handlers_from_pool(pool);

        if (!is_meta && 0x46a8a9CF4Fc8e99EC3A14558ACABC1D93A27de68 == handlers[0]) {
            // Compatible with lending pools in main registry
            return ICurveMainBaseRegistry(0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5).get_underlying_balances(pool);
        } else {
            return ICurveMetaRegister(meta_register()).get_balances(pool);
        }
    }

    function get_tokens(address pool) public view override returns (address[8] memory tokens) {
        if (
            pool == 0x7fC77b5c7614E1533320Ea6DDc2Eb61fa00A9714 || pool == 0xA96A65c051bF88B4095Ee1f2451C2A9d43F53Ae2
                || pool == 0x93054188d876f558f4a66B2EF1d97d16eDf0895B || pool == 0xF9440930043eb3997fc70e1339dBb11F341de7A8
        ) {
            return ICurveMetaRegister(meta_register()).get_coins(pool);
        }
        bool is_meta = ICurveMetaRegister(meta_register()).is_meta(pool);
        address[10] memory handlers = ICurveMetaRegister(meta_register()).get_registry_handlers_from_pool(pool);
        if (!is_meta && 0x46a8a9CF4Fc8e99EC3A14558ACABC1D93A27de68 == handlers[0]) {
            // Compatible with lending pools in main registry
            return ICurveMainBaseRegistry(0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5).get_underlying_coins(pool);
        } else {
            return ICurveMetaRegister(meta_register()).get_coins(pool);
        }
    }

    function get_tokens_with_decimals(address pool) public view override returns (TokenInfo[8] memory tokenInfos) {
        address[8] memory tokens;

        if (
            pool == 0x7fC77b5c7614E1533320Ea6DDc2Eb61fa00A9714 || pool == 0xA96A65c051bF88B4095Ee1f2451C2A9d43F53Ae2
                || pool == 0x93054188d876f558f4a66B2EF1d97d16eDf0895B || pool == 0xF9440930043eb3997fc70e1339dBb11F341de7A8
        ) {
            tokens = ICurveMetaRegister(meta_register()).get_coins(pool);
        } else {
            bool is_meta = ICurveMetaRegister(meta_register()).is_meta(pool);
            address[10] memory handlers = ICurveMetaRegister(meta_register()).get_registry_handlers_from_pool(pool);
            if (!is_meta && 0x46a8a9CF4Fc8e99EC3A14558ACABC1D93A27de68 == handlers[0]) {
                // Compatible with lending pools in main registry
                tokens = ICurveMainBaseRegistry(0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5).get_underlying_coins(pool);
            } else {
                tokens = ICurveMetaRegister(meta_register()).get_coins(pool);
            }
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
                price_scale = new uint256[](n);
                if (pool == 0xDeBF20617708857ebe4F679508E7b7863a8A8EeE) {
                    price_scale[0] = 0;
                    price_scale[1] = 0;
                    price_scale[2] = 0;
                } else if (pool == 0xEB16Ae0052ed37f479f7fe63849198Df1765a733) {
                    price_scale[0] = 10 ** 18;
                    price_scale[1] = 10 ** 18;
                } else {
                    try ICurveNGPool(pool).stored_rates() returns (uint256[] memory result1) {
                        price_scale = result1;
                    } catch {
                        price_scale = new uint256[](n);
                    }
                }
            } catch {
                price_scale = new uint256[](n);
                if (pool == 0x618788357D0EBd8A37e763ADab3bc575D54c2C7d) {
                    address snap = IRai(pool).redemption_price_snap();
                    liquidity = IRai(snap).snappedRedemptionPrice();
                    price_scale[0] = liquidity / 10 ** 9;
                    price_scale[1] = get_virtual_price(ICurveMetaPool(pool).base_pool());
                } else if (
                    pool == 0xBfAb6FA95E0091ed66058ad493189D2cB29385E6
                        || pool == 0x21E27a5E5513D6e65C4f830167390997aA84843a
                        || pool == 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492
                        || pool == 0xfEF79304C80A694dFd9e603D624567D470e1a0e7
                        || pool == 0x1539c2461d7432cc114b0903f1824079BfCA2C92
                ) {
                    uint256[2] memory price_scale0 = ICurveNG2Pool(pool).stored_rates();
                    price_scale[0] = price_scale0[0];
                    price_scale[1] = price_scale0[1];
                } else if (pool == 0xA96A65c051bF88B4095Ee1f2451C2A9d43F53Ae2) {
                    price_scale[0] = 10 ** 18;
                    price_scale[1] = 10 ** 36 / AETH(ICurveSpecialPool(pool).coins(1)).ratio();
                } else if (pool == 0xF9440930043eb3997fc70e1339dBb11F341de7A8) {
                    price_scale[0] = 10 ** 18;
                    price_scale[1] = RETH(ICurveSpecialPool(pool).coins(1)).getExchangeRate();
                }
            }
        }
        A = ICurvePool(pool).A();
        fee = get_fee(pool);
    }
}
