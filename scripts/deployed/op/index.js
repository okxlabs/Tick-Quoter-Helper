module.exports = {
  chainId: 10,
  proxy: "0x296bfb1fb47379189c71f8ab68d4e1e92231a511",
  proxyAdmin: "0xa687b664662b96b180346d699a6d5b42e9b05d31",
  implementation: "0x2a7f3d7486641c77600b9b9256132755c8aebb4f",
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
    poolManager: "0x9a13F98Cb987694c9F086b1F5eB990EeA8264Ec3",
    stateView: "0xc18a3169788f4F75a170290584ECa6395C75EcDb",
    positionManager: "0x3C3Ea4B57a46241e54610e5f022E5c45859a1017"
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
