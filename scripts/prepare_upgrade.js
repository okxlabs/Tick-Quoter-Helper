const path = require('path');
const fs = require('fs');
const { CHAINS, resolveChain } = require('./lib/chains');

const DEPLOYED_DIR = path.join(__dirname, 'deployed');
const UPGRADE_SOL = path.join(__dirname, '..', 'script', 'UpgradeProxy.s.sol');

const { getAddress } = require('@ethersproject/address');

function parseArgs(args) {
  const result = { chain: null, rollback: false, to: null };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--rollback') {
      result.rollback = true;
    } else if (args[i] === '--to' && i + 1 < args.length) {
      result.to = parseInt(args[++i], 10);
    } else if (!args[i].startsWith('-')) {
      result.chain = args[i];
    }
  }

  return result;
}

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log('Usage: node scripts/prepare_upgrade.js <chain> [--rollback [--to <N>]]');
    console.log('');
    console.log('Reads addresses from deployed/<chain>/index.js and outputs the forge script command.');
    console.log('');
    console.log('Modes:');
    console.log('  (default)              Upgrade to stagedImplementation');
    console.log('  --rollback             Rollback to previous implementation (last in history)');
    console.log('  --rollback --to <N>    Rollback to implementationHistory[N] (0-based)');
    console.log('');
    console.log('Supported chains:');
    console.log('  eth, bsc, monad, base, op, arb, polygon, blast, avax, unichain, xlayer');
    process.exit(0);
  }

  const parsed = parseArgs(args);

  const chain = resolveChain(parsed.chain);
  if (!chain) {
    console.error(`Error: Unknown chain "${parsed.chain}"`);
    process.exit(1);
  }

  const chainConfig = CHAINS[chain];
  const indexPath = path.join(DEPLOYED_DIR, chain, 'index.js');

  if (!fs.existsSync(indexPath)) {
    console.error(`Error: ${indexPath} not found`);
    process.exit(1);
  }

  // Clear require cache to get fresh data
  delete require.cache[require.resolve(indexPath)];
  const config = require(indexPath);

  // Validate common fields
  const errors = [];
  if (!config.proxy) errors.push('proxy address not found in config');
  if (!config.proxyAdmin) errors.push('proxyAdmin address not found in config');

  // Determine target implementation
  let newImpl;
  let mode;

  if (parsed.rollback) {
    mode = 'ROLLBACK';
    const history = config.implementationHistory || [];

    if (history.length === 0) {
      errors.push('implementationHistory is empty — nothing to rollback to');
    } else if (parsed.to !== null) {
      if (parsed.to < 0 || parsed.to >= history.length) {
        errors.push(`--to ${parsed.to} out of range (history has ${history.length} entries, index 0-${history.length - 1})`);
      } else {
        newImpl = history[parsed.to];
      }
    } else {
      newImpl = history[history.length - 1];
    }
  } else {
    mode = 'UPGRADE';
    if (!config.stagedImplementation) {
      if (!config.implementation) {
        errors.push('neither stagedImplementation nor implementation found in config');
      } else {
        console.log('⚠️  No stagedImplementation found — using current implementation');
        console.log('   This means you are re-pointing to the same impl. Is this intentional?');
        console.log('');
        newImpl = config.implementation;
      }
    } else {
      newImpl = config.stagedImplementation;
    }
  }

  if (errors.length > 0) {
    console.error('Errors:');
    errors.forEach(e => console.error(`  ❌ ${e}`));
    process.exit(1);
  }

  const proxy = config.proxy;
  const proxyAdmin = config.proxyAdmin;

  console.log(`Preparing ${mode.toLowerCase()} for ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})`);
  console.log('');

  // Report state
  console.log('Addresses:');
  console.log(`  Proxy:              ${proxy}`);
  console.log(`  ProxyAdmin:         ${proxyAdmin}`);
  console.log(`  Current impl:       ${config.implementation}`);
  if (mode === 'UPGRADE' && config.stagedImplementation) {
    console.log(`  Staged impl:        ${config.stagedImplementation} (upgrade target)`);
  }
  if (mode === 'ROLLBACK') {
    const history = config.implementationHistory;
    const idx = parsed.to !== null ? parsed.to : history.length - 1;
    console.log(`  Rollback target:    ${newImpl} (history[${idx}])`);
    console.log(`  History:            ${history.length} entries`);
    history.forEach((addr, i) => {
      const marker = addr === newImpl ? ' ← target' : '';
      console.log(`    [${i}] ${addr}${marker}`);
    });
  } else if (config.implementationHistory && config.implementationHistory.length > 0) {
    console.log(`  History:            ${config.implementationHistory.length} previous implementations`);
  }
  console.log('');

  // Sanity checks
  if (mode === 'UPGRADE' && config.implementation === config.stagedImplementation) {
    console.log('⚠️  stagedImplementation == implementation — already promoted?');
    console.log('   Run: node scripts/post_upgrade.js ' + chain + ' --check');
    console.log('');
  }
  if (newImpl.toLowerCase() === (config.implementation || '').toLowerCase()) {
    console.log('⚠️  Target is the same as current implementation — no-op upgrade');
    console.log('');
  }

  // Write addresses into UpgradeProxy.s.sol
  let sol = fs.readFileSync(UPGRADE_SOL, 'utf8');
  const replacements = [
    ['__PROXY__', getAddress(proxy)],
    ['__PROXY_ADMIN__', getAddress(proxyAdmin)],
    ['__NEW_IMPLEMENTATION__', getAddress(newImpl)],
    ['__CHAIN_ID__', String(chainConfig.chainId)],
  ];

  for (const [placeholder, value] of replacements) {
    if (!sol.includes(placeholder)) {
      console.error(`Error: placeholder ${placeholder} not found in UpgradeProxy.s.sol`);
      console.error('Has the file already been prepared? Run: git checkout -- script/UpgradeProxy.s.sol');
      process.exit(1);
    }
    sol = sol.replace(placeholder, value);
  }

  fs.writeFileSync(UPGRADE_SOL, sol);
  console.log('  Written addresses into script/UpgradeProxy.s.sol');
  console.log('');

  // Output commands
  console.log('============================================================');
  console.log('DRY-RUN COMMAND (simulate without broadcasting):');
  console.log('============================================================');
  console.log('');
  console.log(`forge script script/UpgradeProxy.s.sol:UpgradeProxy --rpc-url ${chain} -vvvv`);
  console.log('');
  console.log('============================================================');
  console.log('BROADCAST COMMAND (execute on-chain):');
  console.log('============================================================');
  console.log('');
  console.log(`forge script script/UpgradeProxy.s.sol:UpgradeProxy --rpc-url ${chain} --broadcast -vvvv`);
  console.log('');

  // Next steps
  console.log('============================================================');
  console.log(`After ${mode.toLowerCase()} completes:`);
  console.log(`  git checkout -- script/UpgradeProxy.s.sol`);
  console.log(`  node scripts/post_upgrade.js ${chain}`);
  console.log('============================================================');
}

main();
