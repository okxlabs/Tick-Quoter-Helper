// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {
    QueryCurveUpgradeableV2,
    ICurveMetaRegister,
    ICurveV2Pool,
    ICurvePool,
    ICurveNGPool,
    IAddressProvider
} from "./QueryCurveUpgradeable.sol";

// https://basescan.org/address/0x3d0143f6453a707b840b6565f959d6cbba86f23e#code
address constant TNG_VIEW_ADDRESS = 0xFcBA2D0133F705DD8bAf250a64f1DE0d7091F5Bd;
address constant TNG_MATH_ADDRESS = 0x2Bd498ae431dC98694010950fcF8ACd3599f5512;

interface ICurveTNGPool {
    function VIEW() external view returns (address);
    function MATH() external view returns (address);
}

interface ICurveTNGMath {
    function version() external view returns (string memory);
}

contract QueryCurveUpgradeableBase is QueryCurveUpgradeableV2 {
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
        //params[0] 1-v1  2-v2  3-NG  4-TNG  5-Unknown
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
            (bool success, bytes memory data) = pool.staticcall(abi.encodeWithSelector(ICurveTNGPool.MATH.selector));
            if (success && data.length >= 32) {
                address mathAddress = abi.decode(data, (address));
                if (mathAddress == TNG_MATH_ADDRESS) {
                    string memory version = ICurveTNGMath(mathAddress).version();
                    if (keccak256(bytes(version)) == keccak256(bytes("v0.1.0"))) {
                        name = 4;
                    } else {
                        name = 5;
                    }
                } else {
                    name = 2;
                }
            } else {
                name = 5;
            }
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

    function migrateLegacyStorage() external {
        require(owner == address(0), "owner already migrated");

        address legacyOwner = _legacyOwner();
        address legacyProvider = _legacyAddressProvider();

        require(legacyOwner != address(0), "legacy owner missing");
        require(legacyProvider != address(0), "legacy provider missing");
        require(msg.sender == legacyOwner, "caller is not legacy owner");

        owner = legacyOwner;
        address_provider = legacyProvider;

        _clearLegacySlots();
    }

    function _legacyOwner() internal view returns (address legacyOwner) {
        bytes32 slot = bytes32(uint256(1));
        assembly {
            legacyOwner := sload(slot)
        }
    }

    function _legacyAddressProvider()
        internal
        view
        returns (address legacyProvider)
    {
        bytes32 slot = bytes32(uint256(0));
        assembly {
            legacyProvider := sload(slot)
        }
    }

    function _clearLegacySlots() internal {
        assembly {
            sstore(0, 0)
            sstore(1, 0)
        }
    }
}
