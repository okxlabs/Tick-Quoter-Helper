module.exports = {
  chainId: 130,
  version: "1.0.0",
  proxy: "0x176804012b76f846ab77b8396a6e5ae074701aae",
  proxyAdmin: "0x9dd8625d4b67dd1dc1ca9521fa884bf388151dd1",
  implementation: "0x26cd030a7307e168ec9ccc30137629a5ed8bacd2",
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
    poolManager: "0x1F98400000000000000000000000000000000004",
    stateView: "0x86e8631a016f9068c3f085faf484ee3f5fdee8f2",
    positionManager: "0x4529a01c7a0410167c5740c487a8de60232617bf"
  },
  stagedImplementation: "0xca3104720e994dcb266b235a45d8ec49ded88638"
};
