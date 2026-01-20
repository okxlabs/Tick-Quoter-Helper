module.exports = {
  chainId: 43114,
  proxy: "0xc0fab674ff7ddf8b891495ba9975b0fe1dcac735",
  proxyAdmin: "0xdeef773d61719a3181e35e9281600db8ba063f71",
  implementation: "0xb70ff46899dded5cd1018fa446d1e78dc0dd6210",
  libraries: {
    QueryAlgebraTicksSuperCompact: "0x6daf1eae61438e3e0b1ab843188040711abe2313",
    QueryZoraTicksSuperCompact: "0x06660e7ccd87cacd8591aed531592063fb82f255",
    QueryUniv4TicksSuperCompact: "0xe733a820f057b7c5fa234dda8761055c1210d292",
    QueryUniv3TicksSuperCompact: "0x78f6b54966f5997bc01c1e9e1bcc491ddec8a4de",
    QueryPancakeInfinityLBReserveSuperCompact: "0x86894feb64ede8b5ae9a16dbd37a866de79f3149",
    QueryIzumiSuperCompact: "0x10b8c37bd234c1f15156bcf3841207415fa0dd3d",
    QueryHorizonTicksSuperCompact: "0xf2308615fd0e270788329f15426935009b7b75dc",
    QueryFluidLite: "0xf0792aaebc112d5bf1282b4d8c0f667e3c386401",
    QueryFluid: "0x6c97aba0a2b2b0de64f83b29a06bdc5f521400c3"
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
