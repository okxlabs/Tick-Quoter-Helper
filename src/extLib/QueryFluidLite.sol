// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AddressCalcs } from "../interface/IFluid.sol";
import "../interface/IFluidLite.sol";

library QueryFluidLite {
    // Copy from ConstantVariables of https://etherscan.io/address/0xBbcb91440523216e2b87052A99F69c604A7b6e00#code
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS / IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant X19 = 0x7ffff;

    struct DexKey {
        address token0;
        address token1;
        bytes32 salt;
    }

    /*//////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/    
    function queryFluidLite(
        address dex_,
        address deployerContract_,
        bytes8 dexId_
    ) public view returns (DexKey memory dexKey_, uint256 centerPrice_, uint256 dexVariables_, uint256 rangeShift_, uint256 thresholdShift_, uint256 centerPriceShift_) {
        dexKey_ = getDexKey(dex_, dexId_);
        centerPrice_ = getCenterPrice(dex_, deployerContract_, dexKey_);
        (dexVariables_, rangeShift_, thresholdShift_, centerPriceShift_) = getShiftStatus(dex_, dexId_);
    }

    /*//////////////////////////////////////////////////////////////
                        Internal Functions
    //////////////////////////////////////////////////////////////*/
    /// @notice Retrieves the dexKey for a given dexId.
    function getDexKey(address dex_, bytes8 dexId_) internal view returns (DexKey memory dexKey_) {
        uint256 length_ = _readStorage(dex_, DexLiteSlotsLink.DEX_LITE_DEXES_LIST_SLOT);
        bytes32 dataSlot_ = keccak256(abi.encode(DexLiteSlotsLink.DEX_LITE_DEXES_LIST_SLOT));

        for (uint256 i = 0; i < length_; i++) {
            uint256 offset_ = i * 3;
            address token0_ = address(uint160(_readStorage(dex_, uint256(dataSlot_) + offset_)));
            address token1_ = address(uint160(_readStorage(dex_, uint256(dataSlot_) + offset_ + 1)));
            bytes32 salt_ = bytes32(_readStorage(dex_, uint256(dataSlot_) + offset_ + 2));

            if (bytes8(keccak256(abi.encode(DexKey(token0_, token1_, salt_)))) == dexId_) {
                return DexKey(token0_, token1_, salt_);
            }
        }
        revert("DexKey not found");
    }

    /// @notice Retrieves the center price for a given dexId.
    function getCenterPrice(address dex_, address deployerContract_, DexKey memory dexKey_) internal view returns (uint256 centerPrice_) {
        bytes8 dexId_ = bytes8(keccak256(abi.encode(dexKey_)));
        uint256 dexVariables_ = _readMappingStorage(dex_, DexLiteSlotsLink.DEX_LITE_DEX_VARIABLES_SLOT, dexId_);
        centerPrice_ = ICenterPriceOfFluidLite(AddressCalcs.addressCalc(deployerContract_, ((dexVariables_ >> DexLiteSlotsLink.BITS_DEX_LITE_DEX_VARIABLES_CENTER_PRICE_CONTRACT_ADDRESS) & X19))).centerPrice(dexKey_.token0, dexKey_.token1);
    }

    /// @notice Retrieves the shift status for a given dexId.
    function getShiftStatus(address dex_, bytes8 dexId_) internal view returns (uint256 dexVariables_,uint256 rangeShift_, uint256 thresholdShift_, uint256 centerPriceShift_) {
        dexVariables_ = _readMappingStorage(dex_, DexLiteSlotsLink.DEX_LITE_DEX_VARIABLES_SLOT, dexId_);
        rangeShift_ = _readMappingStorage(dex_, DexLiteSlotsLink.DEX_LITE_RANGE_SHIFT_SLOT, dexId_);
        thresholdShift_ = _readMappingStorage(dex_, DexLiteSlotsLink.DEX_LITE_THRESHOLD_SHIFT_SLOT, dexId_);
        centerPriceShift_ = _readMappingStorage(dex_, DexLiteSlotsLink.DEX_LITE_CENTER_PRICE_SHIFT_SLOT, dexId_);
    }

    function _readStorage(address dex_, uint256 slot_) internal view returns (uint256 value_) {
        value_ = IFluidDexLite(dex_).readFromStorage(bytes32(slot_));
    }
    
    function _readMappingStorage(address dex_, uint256 baseSlot_, bytes8 key_) internal view returns (uint256 value_) {
        bytes32 slot_ = DexLiteSlotsLink.calculateMappingStorageSlot(baseSlot_, key_);
        value_ = IFluidDexLite(dex_).readFromStorage(slot_);
    }
}