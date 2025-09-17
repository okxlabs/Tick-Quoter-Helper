// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IZumiPool {
    function points(int24 tick) external view returns (uint256, int128, uint256, uint256, bool);

    function pointDelta() external view returns (int24);

    function orderOrEndpoint(int24 tick) external view returns (int24);

    function limitOrderData(int24 point)
        external
        view
        returns (
            uint128 sellingX,
            uint128 earnY,
            uint256 accEarnY,
            uint256 legacyAccEarnY,
            uint128 legacyEarnY,
            uint128 sellingY,
            uint128 earnX,
            uint128 legacyEarnX,
            uint256 accEarnX,
            uint256 legacyAccEarnX
        );

    function pointBitmap(int16 tick) external view returns (uint256);

    function factory() external view returns (address);
}
