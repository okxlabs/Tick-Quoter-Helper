#!/usr/bin/env node
/**
 * Prepare Quote.sol for deployment by replacing addresses from index.js
 */

const fs = require('fs');
const path = require('path');

const QUOTE_SOL_PATH = path.join(__dirname, '../src/Quote.sol');
const DEPLOYED_DIR = path.join(__dirname, 'deployed');

// Try to load ethers once at startup
let getAddressFn = null;
try {
  const ethers = require('ethers');
  getAddressFn = ethers.getAddress || (ethers.utils && ethers.utils.getAddress);
} catch (e) {
  // ethers not installed
}

/**
 * Convert address to checksummed format (EIP-55)
 */
function toChecksumAddress(address) {
  if (!address || address === '0x0000000000000000000000000000000000000000') {
    return '0x0000000000000000000000000000000000000000';
  }
  
  if (getAddressFn) {
    // Convert to lowercase first to avoid checksum validation error
    return getAddressFn(address.toLowerCase());
  }
  
  // Fallback: use simple keccak256 implementation
  const { createHash } = require('crypto');
  const addr = address.toLowerCase().replace('0x', '');
  const hash = createHash('sha3-256').update(Buffer.from(addr, 'utf8')).digest('hex');
  
  let checksummed = '0x';
  for (let i = 0; i < 40; i++) {
    if (parseInt(hash[i], 16) >= 8) {
      checksummed += addr[i].toUpperCase();
    } else {
      checksummed += addr[i];
    }
  }
  
  console.warn(`Warning: Using fallback checksum. Run: npm install ethers`);
  return checksummed;
}

// Supported chains
const CHAIN_ALIASES = {
  eth: 'eth',
  ethereum: 'eth',
  bsc: 'bsc',
  bnb: 'bsc',
  monad: 'monad',
  base: 'base',
  optimism: 'op',
  op: 'op',
  arbitrum: 'arb',
  arb: 'arb',
  polygon: 'polygon',
  matic: 'polygon',
  blast: 'blast',
  avax: 'avax',
  avalanche: 'avax',
  unichain: 'unichain',
};


function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log('Usage: node scripts/prepare_deploy.js <chain>');
    console.log('');
    console.log('Supported chains:');
    console.log('  eth, bsc, monad, base, op, arb, polygon, blast, avax, unichain');
    console.log('');
    console.log('Example:');
    console.log('  node scripts/prepare_deploy.js eth');
    process.exit(0);
  }

  const chainArg = args[0].toLowerCase();
  const chain = CHAIN_ALIASES[chainArg];
  
  if (!chain) {
    console.error(`Error: Unknown chain "${chainArg}"`);
    console.error('Run with --help to see supported chains');
    process.exit(1);
  }

  const indexPath = path.join(DEPLOYED_DIR, chain, 'index.js');
  
  if (!fs.existsSync(indexPath)) {
    console.error(`Error: Config not found at ${indexPath}`);
    process.exit(1);
  }

  // Load chain config
  const config = require(indexPath);
  
  if (!config.uniswapV4) {
    console.error(`Error: uniswapV4 config not found for chain "${chain}"`);
    process.exit(1);
  }

  // Apply checksum to all addresses
  const poolManager = toChecksumAddress(config.uniswapV4.poolManager);
  const stateView = toChecksumAddress(config.uniswapV4.stateView);
  const positionManager = toChecksumAddress(config.uniswapV4.positionManager);
  const fluidLiteDex = toChecksumAddress(config.fluidLite?.dex || '0x0000000000000000000000000000000000000000');
  const fluidLiteDeployer = toChecksumAddress(config.fluidLite?.deployerContract || '0x0000000000000000000000000000000000000000');
  const fluidLiquidity = toChecksumAddress(config.fluid?.liquidity || '0x0000000000000000000000000000000000000000');
  const fluidDexV2 = toChecksumAddress(config.fluid?.dexV2 || '0x0000000000000000000000000000000000000000');

  console.log(`Preparing Quote.sol for ${chain.toUpperCase()} (Chain ID: ${config.chainId})`);
  console.log('');
  console.log('Addresses:');
  console.log(`  POOL_MANAGER:                  ${poolManager}`);
  console.log(`  STATE_VIEW:                    ${stateView}`);
  console.log(`  POSITION_MANAGER:              ${positionManager}`);
  console.log(`  FLUID_LITE_DEX:                ${fluidLiteDex}`);
  console.log(`  FLUID_LITE_DEPLOYER_CONTRACT:  ${fluidLiteDeployer}`);
  console.log(`  FLUID_LIQUIDITY:               ${fluidLiquidity}`);
  console.log(`  FLUID_DEX_V2:                  ${fluidDexV2}`);
  console.log('');

  // Read Quote.sol
  let content = fs.readFileSync(QUOTE_SOL_PATH, 'utf8');

  // Replace addresses using regex
  content = content.replace(
    /address public constant POOL_MANAGER = 0x[a-fA-F0-9]{40};/,
    `address public constant POOL_MANAGER = ${poolManager};`
  );
  
  content = content.replace(
    /address public constant STATE_VIEW = 0x[a-fA-F0-9]{40};/,
    `address public constant STATE_VIEW = ${stateView};`
  );
  
  content = content.replace(
    /address public constant POSITION_MANAGER = 0x[a-fA-F0-9]{40};/,
    `address public constant POSITION_MANAGER = ${positionManager};`
  );
  
  content = content.replace(
    /address public constant FLUID_LITE_DEX = 0x[a-fA-F0-9]{40};/,
    `address public constant FLUID_LITE_DEX = ${fluidLiteDex};`
  );
  
  content = content.replace(
    /address public constant FLUID_LITE_DEPLOYER_CONTRACT = 0x[a-fA-F0-9]{40};/,
    `address public constant FLUID_LITE_DEPLOYER_CONTRACT = ${fluidLiteDeployer};`
  );

  content = content.replace(
    /address public constant FLUID_LIQUIDITY = 0x[a-fA-F0-9]{40};/,
    `address public constant FLUID_LIQUIDITY = ${fluidLiquidity};`
  );

  content = content.replace(
    /address public constant FLUID_DEX_V2 = 0x[a-fA-F0-9]{40};/,
    `address public constant FLUID_DEX_V2 = ${fluidDexV2};`
  );

  // Update comment
  const chainNames = {
    eth: 'Ethereum Mainnet',
    bsc: 'BNB Smart Chain',
    monad: 'Monad',
    base: 'Base',
    op: 'Optimism',
    arb: 'Arbitrum One',
    polygon: 'Polygon',
    blast: 'Blast',
    avax: 'Avalanche C-Chain',
    unichain: 'Unichain',
  };
  
  content = content.replace(
    /\/\/ Core contract addresses \([^)]+\)/,
    `// Core contract addresses (${chainNames[chain] || chain})`
  );

  // Write back
  fs.writeFileSync(QUOTE_SOL_PATH, content);

  console.log('✅ Quote.sol updated successfully!');
  console.log('');
  console.log('Next steps:');
  console.log(`  1. Deploy impl:`);
  console.log(`     forge script script/DeployImpl.s.sol:Deploy --rpc-url ${chain} --broadcast -vvvv`);
  console.log('');
}

main();

