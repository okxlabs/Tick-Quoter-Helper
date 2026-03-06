module.exports = {
  chainId: 43114,
  version: "1.0.0",
  proxy: "0xc0fab674ff7ddf8b891495ba9975b0fe1dcac735",
  proxyAdmin: "0xdeef773d61719a3181e35e9281600db8ba063f71",
  implementation: "0xb70ff46899dded5cd1018fa446d1e78dc0dd6210",
  libraries: {
    QueryAlgebraTicksSuperCompact: "0xd969da8f6c1f88dbc93f4ed8260b56a2017950f5",
    QueryZoraTicksSuperCompact: "0x537a41fe75bdd9b0b8518ee0215d207327b1cc08",
    QueryUniv4TicksSuperCompact: "0x191d584a9127fa69a0609c6c69a0994cfc54b1e6",
    QueryUniv3TicksSuperCompact: "0xf6868efdd409b9ffa2acb8f278aec96de5591833",
    QueryPancakeInfinityLBReserveSuperCompact: "0x14dc72517446b493ebaf5902a955ca64f32dac33",
    QueryIzumiSuperCompact: "0x848fe4a789cb5b47471c27431c954193b0ab0fd7",
    QueryHorizonTicksSuperCompact: "0x98d4edc84208f4ebcd3c0345c708939d35388ffe",
    QueryFluidLite: "0xadbce1282abfc7f7ea33e8575ad51f1e98688339",
    QueryFluid: "0xa61629840e3146646006286f1d3005167cc4e6fc"
  },
  uniswapV4: {
    poolManager: "0x06380c0e0912312b5150364b9dc4542ba0dbbc85",
    stateView: "0xc3c9e198c735a4b97e3e683f391ccbdd60b69286",
    positionManager: "0xb74b1f14d2754acfcbbe1a221023a5cf50ab8acd"
  },
  stagedImplementation: "0x4347b972898b2fd780adbdaa29b4a5160a9f4fe5"
};
