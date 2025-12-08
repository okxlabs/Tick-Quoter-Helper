module.exports = {
  chainId: 130,
  proxy: "0x176804012b76f846ab77b8396a6e5ae074701aae",
  proxyAdmin: "0x9dd8625d4b67dd1dc1ca9521fa884bf388151dd1",
  implementation: "0x26cd030a7307e168ec9ccc30137629a5ed8bacd2",
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
    poolManager: "0x1F98400000000000000000000000000000000004",
    stateView: "0x86e8631a016f9068c3f085faf484ee3f5fdee8f2",
    positionManager: "0x4529a01c7a0410167c5740c487a8de60232617bf"
  },
  fluidLite: {
    dex: "0x0000000000000000000000000000000000000000",
    deployerContract: "0x0000000000000000000000000000000000000000"
  }
};
