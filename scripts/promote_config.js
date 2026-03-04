#!/usr/bin/env node
/**
 * Promote on-chain state into deployed config.
 * Reads on-chain implementation + VERSION via `cast`, auto-detects
 * upgrade / rollback / no-change, and updates index.js accordingly.
 *
 * Usage:
 *   node scripts/promote_config.js <chain> [--check]
 *
 * Flags:
 *   --check   Read-only mode — report what would happen without writing
 */

const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
const { CHAINS, resolveChain, RPC_ENV_MAP } = require('./lib/chains');

const DEPLOYED_DIR = path.join(__dirname, 'deployed');

// EIP-1967 storage slots
const IMPL_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';

function cast(args, rpcUrl) {
  try {
    return execFileSync('cast', [...args, '--rpc-url', rpcUrl], {
      encoding: 'utf8',
      timeout: 30000,
    }).trim();
  } catch (e) {
    return null;
  }
}

function slotToAddress(raw) {
  if (!raw) return null;
  // cast storage returns 0x-prefixed 32-byte hex; take last 20 bytes
  const hex = raw.replace(/^0x/, '').padStart(64, '0');
  return '0x' + hex.slice(24);
}

function main() {
  const args = process.argv.slice(2);
  let chainArg = null;
  let checkOnly = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--check') {
      checkOnly = true;
    } else if (args[i] === '--help' || args[i] === '-h') {
      console.log('Usage: node scripts/promote_config.js <chain> [--check]');
      process.exit(0);
    } else if (!chainArg) {
      chainArg = args[i];
    }
  }

  if (!chainArg) {
    console.error('Error: chain argument required');
    console.error('Usage: node scripts/promote_config.js <chain> [--check]');
    process.exit(1);
  }

  const chain = resolveChain(chainArg);
  if (!chain) {
    console.error(`Error: Unknown chain "${chainArg}"`);
    process.exit(1);
  }

  const chainConfig = CHAINS[chain];
  const rpcEnv = RPC_ENV_MAP[chain];
  const rpcUrl = process.env[rpcEnv];
  if (!rpcUrl) {
    console.log(`Warning: ${rpcEnv} not set, using "${chain}" as rpc alias`);
  }
  const rpc = rpcUrl || chain;

  // Load deployed config
  const indexPath = path.join(DEPLOYED_DIR, chain, 'index.js');
  let config;
  try {
    delete require.cache[require.resolve(indexPath)];
    config = require(indexPath);
  } catch (e) {
    console.error(`Error: Cannot load ${indexPath}`);
    process.exit(1);
  }

  const proxy = config.proxy;
  if (!proxy) {
    console.error('Error: No proxy address in config');
    process.exit(1);
  }

  console.log(`\nPromote config for ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})`);
  console.log('='.repeat(60));
  console.log(`Proxy: ${proxy}`);
  if (checkOnly) console.log('[CHECK MODE — read-only, no writes]');

  // Verify RPC chain ID matches expected
  const rpcChainId = cast(['chain-id'], rpc);
  if (!rpcChainId) {
    console.error(`\nError: Could not read chain ID from RPC "${rpc}"`);
    process.exit(1);
  }
  if (rpcChainId !== String(chainConfig.chainId)) {
    console.error(`\nError: RPC chain ID mismatch — got ${rpcChainId}, expected ${chainConfig.chainId}`);
    process.exit(1);
  }

  // Read on-chain state
  const implRaw = cast(['storage', proxy, IMPL_SLOT], rpc);
  const onChainImpl = slotToAddress(implRaw);

  if (!onChainImpl) {
    console.error('\nError: Could not read on-chain implementation');
    process.exit(1);
  }

  const onChainVersion = cast(['call', proxy, 'VERSION()(string)'], rpc);

  // Validate version format before trusting it
  if (onChainVersion && (onChainVersion.length > 32 || !/^[\w.+-]+$/.test(onChainVersion))) {
    console.error(`\nError: On-chain VERSION has unexpected format: "${onChainVersion}"`);
    process.exit(1);
  }

  console.log(`\n  On-chain impl:    ${onChainImpl}`);
  console.log(`  On-chain VERSION: ${onChainVersion || '(unavailable)'}`);
  console.log(`  Config impl:      ${config.implementation || '(not set)'}`);
  console.log(`  Config staged:    ${config.stagedImplementation || '(not set)'}`);
  console.log(`  Config version:   ${config.version || '(not set)'}`);

  // Auto-detect scenario
  const staged = (config.stagedImplementation || '').toLowerCase();
  const current = (config.implementation || '').toLowerCase();
  const history = Array.isArray(config.implementationHistory) ? config.implementationHistory : [];
  const onChainLower = onChainImpl.toLowerCase();

  let scenario;
  if (onChainLower === current) {
    scenario = 'no-change';
  } else if (staged && onChainLower === staged) {
    scenario = 'upgrade';
  } else if (history.some(h => h.toLowerCase() === onChainLower)) {
    scenario = 'rollback';
  } else {
    scenario = 'unknown';
  }

  console.log(`\n  Scenario: ${scenario.toUpperCase()}`);

  if (scenario === 'unknown') {
    console.error(`\nError: On-chain impl ${onChainImpl} not found in config or history`);
    process.exit(1);
  }

  if (scenario === 'no-change') {
    // Update version if different
    if (onChainVersion && onChainVersion !== config.version) {
      if (checkOnly) {
        console.log(`\n  Would update version: "${config.version}" → "${onChainVersion}"`);
      } else {
        config.version = onChainVersion;
        const content = `module.exports = ${JSON.stringify(config, null, 2).replace(/"([^"]+)":/g, '$1:')};\n`;
        fs.writeFileSync(indexPath, content);
        console.log(`\n  Updated version: "${onChainVersion}"`);
      }
    } else {
      console.log('\n  No changes needed');
    }
    return;
  }

  // Upgrade or rollback — promote config
  if (checkOnly) {
    if (scenario === 'upgrade') {
      console.log(`\n  Would promote: stagedImplementation → implementation`);
      console.log(`  Would archive: ${config.implementation} → implementationHistory`);
    } else {
      const match = history.find(h => h.toLowerCase() === onChainLower);
      console.log(`\n  Would set implementation to: ${match || onChainImpl}`);
      console.log(`  Would archive: ${config.implementation} → implementationHistory`);
    }
    if (onChainVersion) console.log(`  Would update version: "${onChainVersion}"`);
    return;
  }

  // Archive current implementation into history
  if (current) {
    const last = history[history.length - 1];
    if (!last || last.toLowerCase() !== current) {
      history.push(config.implementation);
    }
  }
  config.implementationHistory = history;

  if (scenario === 'upgrade') {
    console.log(`\n  Promoting: stagedImplementation → implementation`);
    config.implementation = config.stagedImplementation;
    delete config.stagedImplementation;
  } else {
    // rollback
    const match = history.find(h => h.toLowerCase() === onChainLower);
    console.log(`\n  Promoting rollback target: ${match || onChainImpl}`);
    config.implementation = match || onChainImpl;
    if (config.stagedImplementation) delete config.stagedImplementation;
  }

  if (onChainVersion) config.version = onChainVersion;

  const content = `module.exports = ${JSON.stringify(config, null, 2).replace(/"([^"]+)":/g, '$1:')};\n`;
  fs.writeFileSync(indexPath, content);
  console.log(`  Written to ${indexPath}`);
  console.log(`  implementation: ${config.implementation}`);
  console.log(`  version: ${config.version || 'N/A'}`);
  console.log(`  history: ${config.implementationHistory.length} entries`);
}

main();
