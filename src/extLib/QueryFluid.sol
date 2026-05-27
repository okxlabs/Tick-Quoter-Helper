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
        (bool s1, bytes memory d1) = pool_.staticcall(abi.encodeWithSelector(IFluidDexT1.constantsView.selector));
        require(s1, "err_quoter_fluid_constantsView_failed");
        IFluidDexT1.ConstantViews memory constantsView_ = abi.decode(d1, (IFluidDexT1.ConstantViews));
        address deployerContract_ = constantsView_.deployerContract;

        // centerPrice_ => center price hook
        centerPrice_ = (dexVariables2_ >> 112) & X30;

        // center price should be fetched from external source. For exmaple, in case of wstETH <> ETH pool,
        // we would want the center price to be pegged to wstETH exchange rate into ETH
        address centerPriceAddr_ = AddressCalcs.addressCalc(deployerContract_, centerPrice_);
        (bool s2, bytes memory d2) = centerPriceAddr_.staticcall(abi.encodeWithSelector(ICenterPriceOfFluid.centerPrice.selector));
        require(s2, "err_quoter_fluid_centerPrice_failed");
        centerPrice_ = abi.decode(d2, (uint256));
    }

    /// @notice Retrieves the shift status of the pool.
    function getShiftStatus(
        address pool_
    ) internal view returns (
        uint256 _rangeShift,
        uint256 _thresholdShift,
        uint256 _centerPriceShift
    ) {
        (bool s3, bytes memory d3) = pool_.staticcall(abi.encodeWithSelector(IFluidDexT1.constantsView.selector));
        require(s3, "err_quoter_fluid_constantsView2_failed");
        IFluidDexT1.ConstantViews memory constantsView_ = abi.decode(d3, (IFluidDexT1.ConstantViews));
        address shift_ = constantsView_.implementations.shift;

        // read storage of variables.sol: https://etherscan.io/address/0x5B6B500981d7Faa8c83Be20514EA8067fbd42304#code#F7#L1
        (bool s4, bytes memory d4) = shift_.staticcall(abi.encodeWithSelector(IShifting.readFromStorage.selector, bytes32(DEX_RANGE_SHIFT_SLOT)));
        require(s4, "err_quoter_fluid_readFromStorage_rangeShift_failed");
        _rangeShift = abi.decode(d4, (uint256));

        (bool s5, bytes memory d5) = shift_.staticcall(abi.encodeWithSelector(IShifting.readFromStorage.selector, bytes32(DEX_THRESHOLD_SHIFT_SLOT)));
        require(s5, "err_quoter_fluid_readFromStorage_thresholdShift_failed");
        _thresholdShift = abi.decode(d5, (uint256));

        (bool s6, bytes memory d6) = shift_.staticcall(abi.encodeWithSelector(IShifting.readFromStorage.selector, bytes32(DEX_CENTER_PRICE_SHIFT_SLOT)));
        require(s6, "err_quoter_fluid_readFromStorage_centerPriceShift_failed");
        _centerPriceShift = abi.decode(d6, (uint256));
    }
}