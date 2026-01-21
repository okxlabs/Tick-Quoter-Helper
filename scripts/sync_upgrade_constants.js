/* eslint-disable no-console */
// Sync upgrade constants (PROXY / PROXY_ADMIN / NEW_IMPLEMENTATION) into a Foundry script
// from `scripts/deployed/<chain>/index.js`.

const fs = require("fs");
const path = require("path");

function usage() {
  // English comments only.
  console.log(`
Usage:
  node scripts/sync_upgrade_constants.js <chainName> [--new-impl 0x...] [--target script/UpgradeProxy.s.sol]

What it does:
  - Reads scripts/deployed/<chain>/index.js
  - Extracts proxy / proxyAdmin / implementation
  - Updates PROXY / PROXY_ADMIN / NEW_IMPLEMENTATION constants in the target Foundry script

Notes:
  - If --new-impl is not provided, it will use the "implementation" field from index.js as NEW_IMPLEMENTATION.
`);
}

function readArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return null;
  return process.argv[idx + 1] || null;
}

function pickAddress(cfgText, key) {
  // Matches: key: "0x...."
  const re = new RegExp(`${key}\\s*:\\s*"(0x[0-9a-fA-F]{40})"`);
  const m = cfgText.match(re);
  if (!m) throw new Error(`Cannot find "${key}" in config`);
  return m[1];
}

function main() {
  const chain = process.argv[2];
  if (!chain) {
    usage();
    process.exit(1);
  }

  const configPath = path.join("scripts", "deployed", chain, "index.js");
  const cfgText = fs.readFileSync(configPath, "utf8");

  const proxy = pickAddress(cfgText, "proxy");
  const proxyAdmin = pickAddress(cfgText, "proxyAdmin");
  const implementation = pickAddress(cfgText, "implementation");

  const newImplArg = readArg("--new-impl");
  const newImpl = newImplArg || implementation;

  const targetPath = readArg("--target") || path.join("script", "UpgradeProxy.s.sol");
  const src = fs.readFileSync(targetPath, "utf8");

  // Emit EIP-55 checksummed address literals (preferred by linters/tooling).
  let getAddressFn = null;
  try {
    // eslint-disable-next-line global-require
    const ethers = require("ethers");
    getAddressFn = ethers.getAddress || (ethers.ethers && ethers.ethers.getAddress) || null;
  } catch (_) {
    // Ignore: will fall back to raw address.
  }

  const asAddressLiteral = (addr) => (getAddressFn ? getAddressFn(addr) : addr);

  const replacement = {
    PROXY: `address internal constant PROXY = ${asAddressLiteral(proxy)};`,
    PROXY_ADMIN: `address internal constant PROXY_ADMIN = ${asAddressLiteral(proxyAdmin)};`,
    NEW_IMPLEMENTATION: `address internal constant NEW_IMPLEMENTATION = ${asAddressLiteral(newImpl)};`,
  };

  const out = src
    .replace(/^(\s*)address\s+internal\s+constant\s+PROXY\s*=.*;.*$/m, `$1${replacement.PROXY}`)
    .replace(/^(\s*)address\s+internal\s+constant\s+PROXY_ADMIN\s*=.*;.*$/m, `$1${replacement.PROXY_ADMIN}`)
    .replace(
      /^(\s*)address\s+internal\s+constant\s+NEW_IMPLEMENTATION\s*=.*;.*$/m,
      `$1${replacement.NEW_IMPLEMENTATION}`
    );

  fs.writeFileSync(targetPath, out);

  console.log("Updated:", targetPath);
  console.log("  proxy       =", proxy);
  console.log("  proxyAdmin  =", proxyAdmin);
  console.log("  newImpl     =", newImpl);
  console.log("");
  console.log("Next:");
  console.log(`  forge script ${targetPath}:UpgradeProxy --rpc-url $RPC_URL --broadcast -vvvv`);
}

main();


