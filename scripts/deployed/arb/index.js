module.exports = {
  chainId: 42161,
  proxy: "0x2303669f3d9816b4cffc42ec13bf7484d284fd16",
  proxyAdmin: "0x667500c9697b475dda97ae7ba0b1a938cbc4856d",
  implementation: "0xcebb810f65141687fb2f571ff82ed728584f808d",
  libraries: {
    QueryAlgebraTicksSuperCompact: "0x7720a57fce419963108a4ca9e5131d0c39d6a556",
    QueryZoraTicksSuperCompact: "0x7856f02e7080d507c08abb85058976761f0ab0e1",
    QueryUniv4TicksSuperCompact: "0x1d3d302185e032e454ad50067987169d6a322c19",
    QueryUniv3TicksSuperCompact: "0x5e916b28c62d0752a1c953d96c400efb330b6815",
    QueryPancakeInfinityLBReserveSuperCompact: "0x600c6d5c1f15726a711d6d71a4205add668d5374",
    QueryIzumiSuperCompact: "0x1792f5f1214ade56c08ab9689f96f2e861a5f264",
    QueryHorizonTicksSuperCompact: "0x2a741b29212d410440a9b782ee85c8939ad7f172",
    QueryFluidLite: "0xa86d99e80cf3cc61a256bf443483f0f75f74f57f",
    QueryFluid: "0xac7e7a13d62d817c88531710fa308a766299f644"
  },
  uniswapV4: {
    poolManager: "0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32",
    stateView: "0x76Fd297e2D437cd7f76d50F01AfE6160f86e9990",
    positionManager: "0xd88F38F930b7952f2DB2432Cb002E7abbF3dD869"
  },
  fluidLite: {
    dex: "0x0000000000000000000000000000000000000000",
    deployerContract: "0x0000000000000000000000000000000000000000"
  },
  fluid: {
    liquidity: "0x52Aa899454998Be5b000Ad077a46Bbe360F4e497",
    dexV2: "0x7822B3944B1a68B231a6e7F55B57967F28BB369e"
  }
};
