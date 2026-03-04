/**
 * Shared chain configuration for deployment scripts.
 * Single source of truth for CHAINS, CHAIN_ALIASES, LIB_MAPPING, and RPC_ENV_MAP.
 */

const CHAINS = {
  eth: { chainId: 1, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=1', verifier: 'etherscan' },
  bsc: { chainId: 56, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=56', verifier: 'etherscan' },
  monad: { chainId: 143, verifierUrl: 'https://sourcify-api-monad.blockvision.org/', verifier: 'sourcify' },
  base: { chainId: 8453, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=8453', verifier: 'etherscan' },
  op: { chainId: 10, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=10', verifier: 'etherscan' },
  arb: { chainId: 42161, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=42161', verifier: 'etherscan' },
  polygon: { chainId: 137, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=137', verifier: 'etherscan' },
  blast: { chainId: 81457, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=81457', verifier: 'etherscan' },
  avax: { chainId: 43114, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=43114', verifier: 'etherscan' },
  unichain: { chainId: 130, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=130', verifier: 'etherscan' },
  xlayer: { chainId: 196, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/xlayer', verifier: 'oklink' },
};

const CHAIN_ALIASES = {
  eth: 'eth', ethereum: 'eth',
  bsc: 'bsc', bnb: 'bsc',
  monad: 'monad',
  base: 'base',
  optimism: 'op', op: 'op',
  arbitrum: 'arb', arb: 'arb',
  polygon: 'polygon', matic: 'polygon',
  blast: 'blast',
  avax: 'avax', avalanche: 'avax',
  unichain: 'unichain',
  xlayer: 'xlayer',
};

const LIB_MAPPING = {
  QueryAlgebraTicksSuperCompact: 'src/extLib/QueryAlgebraTicksSuperCompact.sol:QueryAlgebraTicksSuperCompact',
  QueryZoraTicksSuperCompact: 'src/extLib/QueryZoraTicksSuperCompact.sol:QueryZoraTicksSuperCompact',
  QueryUniv4TicksSuperCompact: 'src/extLib/QueryUniv4TicksSuperCompact.sol:QueryUniv4TicksSuperCompact',
  QueryUniv3TicksSuperCompact: 'src/extLib/QueryUniv3TicksSuperCompact.sol:QueryUniv3TicksSuperCompact',
  QueryPancakeInfinityLBReserveSuperCompact: 'src/extLib/QueryPancakeInfinityLBReserveSuperCompact.sol:QueryPancakeInfinityLBReserveSuperCompact',
  QueryIzumiSuperCompact: 'src/extLib/QueryIzumiSuperCompact.sol:QueryIzumiSuperCompact',
  QueryHorizonTicksSuperCompact: 'src/extLib/QueryHorizonTicksSuperCompact.sol:QueryHorizonTicksSuperCompact',
  QueryFluidLite: 'src/extLib/QueryFluidLite.sol:QueryFluidLite',
  QueryFluid: 'src/extLib/QueryFluid.sol:QueryFluid',
};

const RPC_ENV_MAP = {
  eth: 'ETH_RPC_URL',
  bsc: 'BSC_RPC_URL',
  monad: 'MONAD_RPC_URL',
  base: 'BASE_RPC_URL',
  op: 'OP_RPC_URL',
  arb: 'ARB_RPC_URL',
  polygon: 'POLYGON_RPC_URL',
  blast: 'BLAST_RPC_URL',
  avax: 'AVAX_RPC_URL',
  unichain: 'UNICHAIN_RPC_URL',
  xlayer: 'XLAYER_RPC_URL',
};

function resolveChain(chainArg) {
  const normalized = chainArg.toLowerCase();
  const chain = CHAIN_ALIASES[normalized];
  if (!chain || !CHAINS[chain]) return null;
  return chain;
}

module.exports = { CHAINS, CHAIN_ALIASES, LIB_MAPPING, RPC_ENV_MAP, resolveChain };
