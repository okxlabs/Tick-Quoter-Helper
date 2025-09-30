// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interface/IFluid.sol";

library QueryFluid {
    /*//////////////////////////////////////////////////////////////
                          CONSTANTS / IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant X30 = 0x3fffffff;

    /// @dev storage slot for range shift
    uint256 internal constant DEX_RANGE_SHIFT_SLOT = 7;
    /// @dev storage slot for threshold shift
    uint256 internal constant DEX_THRESHOLD_SHIFT_SLOT = 8;
    /// @dev storage slot for center price shift
    uint256 internal constant DEX_CENTER_PRICE_SHIFT_SLOT = 9;

    /*//////////////////////////////////////////////////////////////
                    External Functions
    //////////////////////////////////////////////////////////////*/
    function queryFluid(
        address pool_,
        uint256 dexVariables2_
    ) public view returns (uint256 centerPrice_, uint256 rangeShift_, uint256 thresholdShift_, uint256 centerPriceShift_) {
        centerPrice_ = getCenterPrice(pool_, dexVariables2_);
        (rangeShift_, thresholdShift_, centerPriceShift_) = getShiftStatus(pool_);
    }

    /*//////////////////////////////////////////////////////////////
                    Internal Functions
    //////////////////////////////////////////////////////////////*/
    /// @notice Retrieves the center price of the pool.
    function getCenterPrice(
        address pool_,
        uint256 dexVariables2_
    ) internal view returns (uint256 centerPrice_) {
        // Get deployerContract and shift address
        IFluidDexT1.ConstantViews memory constantsView_ = IFluidDexT1(pool_).constantsView();
        address deployerContract_ = constantsView_.deployerContract;

        // centerPrice_ => center price hook
        centerPrice_ = (dexVariables2_ >> 112) & X30;

        // center price should be fetched from external source. For exmaple, in case of wstETH <> ETH pool,
        // we would want the center price to be pegged to wstETH exchange rate into ETH
        centerPrice_ = ICenterPriceOfFluid(AddressCalcs.addressCalc(deployerContract_, centerPrice_)).centerPrice();
    }

    /// @notice Retrieves the shift status of the pool.
    function getShiftStatus(
        address pool_
    ) internal view returns (
        uint256 _rangeShift,
        uint256 _thresholdShift,
        uint256 _centerPriceShift
    ) {
        IFluidDexT1.ConstantViews memory constantsView_ = IFluidDexT1(pool_).constantsView();
        address shift_ = constantsView_.implementations.shift;

        // read storage of variables.sol: https://etherscan.io/address/0x5B6B500981d7Faa8c83Be20514EA8067fbd42304#code#F7#L1
        _rangeShift = IShifting(shift_).readFromStorage(bytes32(DEX_RANGE_SHIFT_SLOT));
        _thresholdShift = IShifting(shift_).readFromStorage(bytes32(DEX_THRESHOLD_SHIFT_SLOT));
        _centerPriceShift = IShifting(shift_).readFromStorage(bytes32(DEX_CENTER_PRICE_SHIFT_SLOT));
    }
}