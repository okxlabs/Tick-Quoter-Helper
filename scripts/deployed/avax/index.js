module.exports = {
  chainId: 43114,
  proxy: "0xc0fab674ff7ddf8b891495ba9975b0fe1dcac735",
  proxyAdmin: "0xdeef773d61719a3181e35e9281600db8ba063f71",
  implementation: "0xd22cac235c9d2a8252b0e02985a6c67a959b21b0",
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
    poolManager: "0x06380c0e0912312b5150364b9dc4542ba0dbbc85",
    stateView: "0xc3c9e198c735a4b97e3e683f391ccbdd60b69286",
    positionManager: "0xb74b1f14d2754acfcbbe1a221023a5cf50ab8acd"
  },
  fluidLite: {
    dex: "0x0000000000000000000000000000000000000000",
    deployerContract: "0x0000000000000000000000000000000000000000"
  },
  fluid: {
    liquidity: "0x0000000000000000000000000000000000000000",
    dexV2: "0x0000000000000000000000000000000000000000"
  }
};
