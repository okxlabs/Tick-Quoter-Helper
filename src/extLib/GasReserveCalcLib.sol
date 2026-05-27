// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title GasReserveCalcLib
/// @notice Library for calculating gas reserve needed for returning tick data arrays
/// @dev The gas cost for returning bytes arrays is not purely linear due to EVM memory expansion costs.
///      According to the Ethereum Yellow Paper (Appendix H), memory cost follows:
///      C_mem(a) = 3a + floor(a^2 / 512), where `a` is memory size in words.
///      This quadratic component means larger arrays require proportionally more gas.
///
///      The formula `(tickNum + OFFSET)^2 / 10` was derived empirically through testing
///      with TransparentUpgradeableProxy to ensure sufficient gas for:
///      1. Trimming the pre-allocated array to actual size
///      2. ABI encoding the return data
///      3. Copying returndata through the proxy (delegatecall overhead)
///
///      OFFSET=650 provides a minimum 10% safety margin across all tested tick counts (10-5000).
library GasReserveCalcLib {
    /// @notice Offset constant for gas reserve calculation
    /// @dev Empirically determined to provide >= 10% margin for tick counts up to 5000
    uint256 internal constant OFFSET = 650;

    /// @notice Calculate the gas reserve needed for returning tick data
    /// @param tickNum The number of ticks (each tick = 32 bytes in the return array)
    /// @return gasReserve The amount of gas to reserve for return operations
    function calcGasReserve(uint256 tickNum) internal pure returns (uint256) {
        return (tickNum + OFFSET) * (tickNum + OFFSET) / 10;
    }
}