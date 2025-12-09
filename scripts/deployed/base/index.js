module.exports = {
  chainId: 8453,
  proxy: "0x722db4f285f8bd91ef7af6da397e83f7fa4e80a7",
  proxyAdmin: "0xeac3f383d26967952be615566360b64177f5d450",
  implementation: "0x92487d624d1f4d5dac6575dccb529728ec4c9f0d",
  libraries: {
    QueryUniv3TicksSuperCompact: "0x3042010469dfd519c19c21f09ae19ea3b60e7dd3",
    QueryUniv4TicksSuperCompact: "0x23ea15135047e7a369f6f7dde640fe60c928c4af",
    QueryAlgebraTicksSuperCompact: "0xe2ae3323bf9ccca1122bc999613ddadf0b7f886e",
    QueryHorizonTicksSuperCompact: "0x6b957ed1e3bb0e26961b66d7727fb11ed2e77460",
    QueryIzumiSuperCompact: "0xdfbfd2113bff6cd248ec1760df109beb244b2e5a",
    QueryZoraTicksSuperCompact: "0xc175d951110371a19a34e5eb321cac335d3c9e7e",
    QueryPancakeInfinityLBReserveSuperCompact: "0xd972d8ee0b463bf48b50ea17fa6591d8eadca363",
    QueryFluid: "0x4950358075df0f4f76ad4a62755605a80fb66b0c",
    QueryFluidLite: "0xf81805e9034f4f6b3d639517cf4760d2e924fc39",
  },
  uniswapV4: {
    poolManager: "0x498581fF718922c3f8e6A244956aF099B2652b2b",
    stateView: "0xA3c0c9b65baD0b08107Aa264b0f3dB444b867A71",
    positionManager: "0x7C5f5A4bBd8fD63184577525326123B519429bDc",
  },
  fluidLite: {
    dex: "0x0000000000000000000000000000000000000000",
    deployerContract: "0x0000000000000000000000000000000000000000",
  },
  fluid: {
    liquidity: "0x0000000000000000000000000000000000000000",
    dexV2: "0x0000000000000000000000000000000000000000",
  },
};
