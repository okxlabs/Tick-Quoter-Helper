module.exports = {
  chainId: 42161,
  version: "1.0.0",
  proxy: "0x2303669f3d9816b4cffc42ec13bf7484d284fd16",
  proxyAdmin: "0x667500c9697b475dda97ae7ba0b1a938cbc4856d",
  implementation: "0xcebb810f65141687fb2f571ff82ed728584f808d",
  libraries: {
    QueryAlgebraTicksSuperCompact: "0xd969da8f6c1f88dbc93f4ed8260b56a2017950f5",
    QueryZoraTicksSuperCompact: "0x537a41fe75bdd9b0b8518ee0215d207327b1cc08",
    QueryUniv4TicksSuperCompact: "0x191d584a9127fa69a0609c6c69a0994cfc54b1e6",
    QueryUniv3TicksSuperCompact: "0xf6868efdd409b9ffa2acb8f278aec96de5591833",
    QueryPancakeInfinityLBReserveSuperCompact: "0x14dc72517446b493ebaf5902a955ca64f32dac33",
    QueryIzumiSuperCompact: "0x848fe4a789cb5b47471c27431c954193b0ab0fd7",
    QueryHorizonTicksSuperCompact: "0x98d4edc84208f4ebcd3c0345c708939d35388ffe",
    QueryFluidLite: "0xadbce1282abfc7f7ea33e8575ad51f1e98688339",
    QueryFluid: "0xa61629840e3146646006286f1d3005167cc4e6fc",
    QueryFluidDexV2D3D4: "0x37ee4131eca92D4986B94C31326556d4F994Dc17"
  },
  uniswapV4: {
    poolManager: "0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32",
    stateView: "0x76Fd297e2D437cd7f76d50F01AfE6160f86e9990",
    positionManager: "0xd88F38F930b7952f2DB2432Cb002E7abbF3dD869"
  },
  stagedImplementation: "0x316374bc97094a36170803d1aff51e1fbeed0a29"
};
