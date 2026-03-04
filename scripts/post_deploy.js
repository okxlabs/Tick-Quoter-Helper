const fs = require('fs');
const path = require('path');
const { CHAINS, CHAIN_ALIASES, LIB_MAPPING } = require('./lib/chains');

const BROADCAST_DIR = path.join(__dirname, '../broadcast');
const DEPLOYED_DIR = path.join(__dirname, 'deployed');

function readBroadcast(scriptName, chainId) {
  const broadcastPath = path.join(BROADCAST_DIR, scriptName, String(chainId), 'run-latest.json');
  if (!fs.existsSync(broadcastPath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(broadcastPath, 'utf8'));
}

function extractAddresses(broadcast) {
  const addresses = {
    implementation: '',
    proxy: '',
    proxyAdmin: '',
    libraries: {},
  };

  if (!broadcast || !broadcast.transactions) return addresses;

  for (const tx of broadcast.transactions) {
    if (!tx.contractName || !tx.contractAddress) continue;
    
    const name = tx.contractName;
    const addr = tx.contractAddress;

    if (name === 'QueryData') {
      addresses.implementation = addr;
    } else if (name === 'TransparentUpgradeableProxy') {
      addresses.proxy = addr;
    } else if (name === 'ProxyAdmin') {
      addresses.proxyAdmin = addr;
    } else if (LIB_MAPPING[name]) {
      addresses.libraries[name] = addr;
    }
  }

  return addresses;
}

function updateIndexJs(chain, addresses) {
  const indexPath = path.join(DEPLOYED_DIR, chain, 'index.js');
  
  if (!fs.existsSync(indexPath)) {
    console.error(`Error: ${indexPath} not found`);
    return false;
  }

  const config = require(indexPath);

  // Track implementation history on upgrade
  if (addresses.implementation && config.implementation
      && addresses.implementation.toLowerCase() !== config.implementation.toLowerCase()) {
    if (!Array.isArray(config.implementationHistory)) {
      config.implementationHistory = [];
    }
    const last = config.implementationHistory[config.implementationHistory.length - 1];
    if (!last || last.toLowerCase() !== config.implementation.toLowerCase()) {
      config.implementationHistory.push(config.implementation);
    }
  }

  // Update addresses
  if (addresses.implementation) config.implementation = addresses.implementation;
  if (addresses.proxy) config.proxy = addresses.proxy;
  if (addresses.proxyAdmin) config.proxyAdmin = addresses.proxyAdmin;
  if (Object.keys(addresses.libraries).length > 0) {
    config.libraries = addresses.libraries;
  }

  // Write back
  const content = `module.exports = ${JSON.stringify(config, null, 2).replace(/"([^"]+)":/g, '$1:')};\n`;
  fs.writeFileSync(indexPath, content);
  
  return true;
}

function generateVerifyCommand(chain, addresses, chainConfig) {
  if (!addresses.implementation) {
    return null;
  }

  const libs = Object.entries(addresses.libraries)
    .map(([name, addr]) => `  --libraries ${LIB_MAPPING[name]}:${addr}`)
    .join(' \\\n');

  if (chain === 'xlayer') {
    return `forge verify-contract \\
  ${addresses.implementation} \\
  src/Quote.sol:QueryData \\
  --verifier ${chainConfig.verifier} \\
  --verifier-url "${chainConfig.verifierUrl}" \\
  --num-of-optimizations 200 \\
  --compiler-version v0.8.17+commit.8df45f5f \\
${libs} \\
  --watch`;
  }

  if (chainConfig.verifier === 'sourcify') {
    return `forge verify-contract \\
  --rpc-url ${chain} \\
  --verifier sourcify \\
  --verifier-url '${chainConfig.verifierUrl}' \\
  --compiler-version 0.8.17 \\
  --num-of-optimizations 200 \\
${libs} \\
  ${addresses.implementation} \\
  src/Quote.sol:QueryData`;
  }

  return `forge verify-contract \\
  ${addresses.implementation} \\
  src/Quote.sol:QueryData \\
  --verifier etherscan \\
  --verifier-url "${chainConfig.verifierUrl}" \\
  --etherscan-api-key $ETHERSCAN_API_KEY \\
  --num-of-optimizations 200 \\
  --compiler-version v0.8.17+commit.8df45f5f \\
${libs} \\
  --watch`;
}

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log('Usage: node scripts/post_deploy.js <chain>');
    console.log('');
    console.log('Reads deployment data from broadcast/ and updates index.js');
    console.log('');
    console.log('Supported chains:');
    console.log('  eth, bsc, monad, base, op, arb, polygon, blast, avax, unichain, xlayer');
    process.exit(0);
  }

  const chainArg = args[0].toLowerCase();
  const chain = CHAIN_ALIASES[chainArg];

  if (!chain || !CHAINS[chain]) {
    console.error(`Error: Unknown chain "${chainArg}"`);
    process.exit(1);
  }

  const chainConfig = CHAINS[chain];
  console.log(`Processing ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})`);
  console.log('');

  // Read impl deployment
  const implBroadcast = readBroadcast('DeployImpl.s.sol', chainConfig.chainId);
  const implAddresses = extractAddresses(implBroadcast);

  // Read proxy deployment
  const proxyBroadcast = readBroadcast('DeployProxy.s.sol', chainConfig.chainId);
  const proxyAddresses = extractAddresses(proxyBroadcast);

  // Merge addresses
  const addresses = {
    implementation: implAddresses.implementation || proxyAddresses.implementation,
    proxy: proxyAddresses.proxy,
    proxyAdmin: proxyAddresses.proxyAdmin,
    libraries: { ...implAddresses.libraries, ...proxyAddresses.libraries },
  };

  console.log('Found addresses:');
  console.log(`  Implementation: ${addresses.implementation || '(not found)'}`);
  console.log(`  Proxy:          ${addresses.proxy || '(not found)'}`);
  console.log(`  ProxyAdmin:     ${addresses.proxyAdmin || '(not found)'}`);
  console.log(`  Libraries:      ${Object.keys(addresses.libraries).length} found`);
  console.log('');

  // Update index.js
  if (updateIndexJs(chain, addresses)) {
    console.log(`✅ Updated scripts/deployed/${chain}/index.js`);
    console.log('');
  }

    // Generate verify command
    const verifyCmd = generateVerifyCommand(chain, addresses, chainConfig);
    if (verifyCmd) {
      console.log('='.repeat(60));
      console.log('VERIFY IMPLEMENTATION COMMAND:');
      console.log('='.repeat(60));
      console.log('');
      console.log(verifyCmd);
      console.log('');
    }

    // Generate proxy deploy command
    console.log('='.repeat(60));
    console.log('DEPLOY PROXY COMMAND:');
    console.log('='.repeat(60));
    console.log('');
    console.log(`IMPLEMENTATION=${addresses.implementation} \\`);
    console.log(`  forge script script/DeployProxy.s.sol:DeployProxy \\`);
    console.log(`  --rpc-url ${chain} \\`);
    console.log(`  --broadcast \\`);
    if (chainConfig.verifier === 'etherscan') {
      console.log(`  --verify \\`);
      console.log(`  --verifier ${chainConfig.verifier} \\`);
      console.log(`  --verifier-url "${chainConfig.verifierUrl}" \\`);
      console.log(`  --etherscan-api-key $ETHERSCAN_API_KEY \\`);
    } else if (chainConfig.verifier === 'oklink') {
      console.log(`  --verify \\`);
      console.log(`  --verifier ${chainConfig.verifier} \\`);
      console.log(`  --verifier-url "${chainConfig.verifierUrl}" \\`);
    }
    console.log(`  -vvvv`);
    console.log('');
  }

main();

