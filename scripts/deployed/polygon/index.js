module.exports = {
  chainId: 137,
  version: "1.0.0",
  proxy: "0xdea1ccaf997ec68fe2e9839a581e493d0e984a06",
  proxyAdmin: "0xbcf971dda988a5b708e5b107b5a6c9be54097967",
  implementation: "0x0f573CeC04483a8F344380217E9cF02A838DF839",
  stagedImplementation: "0xc175d951110371a19a34e5eb321cac335d3c9e7e",
  libraries: {
    QueryAlgebraTicksSuperCompact: "0xd969Da8F6c1f88DBC93f4ed8260B56A2017950F5",
    QueryFluid: "0xA61629840e3146646006286F1d3005167cc4E6FC",
    QueryFluidDexV2D3D4: "0x37ee4131eca92D4986B94C31326556d4F994Dc17",
    QueryFluidLite: "0xadbCe1282abfC7f7EA33E8575aD51f1E98688339",
    QueryHorizonTicksSuperCompact: "0x98d4EDC84208F4EbCD3C0345C708939d35388FfE",
    QueryIzumiSuperCompact: "0x848fe4A789Cb5b47471C27431c954193b0Ab0fd7",
    QueryPancakeInfinityLBReserveSuperCompact: "0x14DC72517446B493eBaf5902a955cA64F32DAC33",
    QueryUniv3TicksSuperCompact: "0xF6868EFdD409B9fFa2ACb8F278aEc96de5591833",
    QueryUniv4TicksSuperCompact: "0x191d584a9127fa69a0609c6C69a0994cFC54b1e6",
    QueryZoraTicksSuperCompact: "0x537a41FE75bdd9b0B8518ee0215d207327B1cC08"
  },
  uniswapV4: {
    poolManager: "0x67366782805870060151383f4bbff9dab53e5cd6",
    stateView: "0x5ea1bd7974c8a611cbab0bdcafcb1d9cc9b3ba5a",
    positionManager: "0x1ec2ebf4f37e7363fdfe3551602425af0b3ceef9"
  },
  fluid: {
    liquidity: "0x52Aa899454998Be5b000Ad077a46Bbe360F4e497",
    dexV2: "0x7822B3944B1a68B231a6e7F55B57967F28BB369e"
  }
};
