# Tick-Quoter-Helper — Agent Operations Manual

## Project Overview

On-chain quoter contracts for DEX aggregation. Primary contract:

- **Quote (TransparentProxy)** — `src/Quote.sol` → `QueryData` contract. Uses OpenZeppelin v4.5 `TransparentUpgradeableProxy` + `ProxyAdmin`. Per-chain addresses are hardcoded as constants in `Quote.sol` before each deployment.

## Chain Configuration

11 supported chains, defined in `scripts/lib/chains.js`:

| Chain     | Alias(es)         | Chain ID | Verifier  |
|-----------|-------------------|----------|-----------|
| eth       | ethereum          | 1        | etherscan |
| bsc       | bnb               | 56       | etherscan |
| monad     |                   | 143      | sourcify  |
| base      |                   | 8453     | etherscan |
| op        | optimism          | 10       | etherscan |
| arb       | arbitrum          | 42161    | etherscan |
| polygon   | matic             | 137      | etherscan |
| blast     |                   | 81457    | etherscan |
| avax      | avalanche         | 43114    | etherscan |
| unichain  |                   | 130      | etherscan |
| xlayer    |                   | 196      | oklink    |

RPC URLs are configured in `foundry.toml` under `[rpc_endpoints]` using env vars (e.g., `ETH_RPC_URL`, `BASE_RPC_URL`).

## Address Registry

Deployed addresses live in `scripts/deployed/<chain>/index.js`. Each exports:
```js
module.exports = {
  chainId: 8453,
  version: "1.0.0",
  proxy: "0x...",
  proxyAdmin: "0x...",
  implementation: "0x...",         // active on-chain implementation
  stagedImplementation: "0x...",   // deployed but not yet upgraded (temporary)
  implementationHistory: ["0xV1...", "0xV2..."],  // oldest → newest
  libraries: { QueryUniv3TicksSuperCompact: "0x...", ... },
  uniswapV4: { poolManager: "0x...", stateView: "0x...", positionManager: "0x..." },
  fluidLite: { dex: "0x...", deployerContract: "0x..." },
  fluid: { liquidity: "0x...", dexV2: "0x..." },
};
```

The `version` field tracks the contract VERSION() constant. `QueryData` exposes `string public constant VERSION`. The `post_upgrade.js` script reads VERSION() on-chain and writes it back to index.js.

### Staged Implementation Workflow

When `post_deploy.js` extracts a new implementation address, it writes to `stagedImplementation` instead of overwriting `implementation`. This keeps `implementation` reflecting the actual on-chain proxy target until the upgrade is confirmed:

1. **Deploy impl** → `post_deploy.js` sets `stagedImplementation` (first-time deploy writes directly to `implementation`)
2. **Upgrade proxy** → human executes upgrade transaction
3. **Promote config** → `post_upgrade.js` detects the upgrade, moves `stagedImplementation` → `implementation`, archives the old impl in `implementationHistory`, and updates `version`

The script also handles rollback detection: if the on-chain impl matches a `implementationHistory` entry, it promotes accordingly.

### Implementation History

When upgrading or rolling back, the previous implementation address is automatically appended to `implementationHistory`. This enables rollback to any prior version. History is ordered oldest → newest. The `--to <N>` flag selects a specific index (0-based); default is the last entry (most recent previous version).

### Environment Variables

Configured in `.env` (never committed):
- `ETHERSCAN_API_KEY` — for source code verification
- `<CHAIN>_RPC_URL` — per-chain RPC endpoints (e.g., `ETH_RPC_URL`, `BASE_RPC_URL`)

## Key Scripts

| Script | Purpose |
|--------|---------|
| `scripts/prepare_deploy.js <chain>` | Writes chain addresses into `src/Quote.sol` constants |
| `scripts/post_deploy.js <chain>` | Reads broadcast output → writes `stagedImplementation` to `deployed/<chain>/index.js` |
| `scripts/prepare_upgrade.js <chain> [--rollback [--to N]]` | Reads index.js → writes addresses into `UpgradeProxy.s.sol`, outputs forge command |
| `scripts/post_upgrade.js <chain>` | Read on-chain state via `cast`; promote staged config; `--check` for read-only |
| `scripts/lib/chains.js` | Shared chain config (CHAINS, aliases, library mapping) |

## Forge Scripts

| Script | Purpose |
|--------|---------|
| `script/DeployImpl.s.sol:Deploy` | Deploy QueryData implementation |
| `script/DeployProxy.s.sol:DeployProxy` | Deploy TransparentProxy + ProxyAdmin |
| `script/UpgradeProxy.s.sol:UpgradeProxy` | Upgrade proxy to new implementation (addresses written by `prepare_upgrade.js`) |

## Safety Rules

1. **Always dry-run before broadcast** — `forge script ... -vvvv` (no `--broadcast`) first
2. **Validate after every deployment** — `node scripts/post_upgrade.js <chain> --check`
3. **Never commit `.env`** — it contains private keys
4. **Restore Quote.sol after deploy** — `git checkout -- src/Quote.sol` (prepare_deploy modifies it temporarily)
5. **Restore UpgradeProxy.s.sol after upgrade** — `git checkout -- script/UpgradeProxy.s.sol` (prepare_upgrade modifies it temporarily)
6. **Update VERSION on upgrade** — bump the `VERSION` constant in `src/Quote.sol` before deploying a new implementation
7. **Deploy and upgrade are separate steps** — deploy implementation first, then upgrade proxy. Never bundle them into one operation
8. **Validate after upgrade/rollback** — use `post_upgrade.js` to confirm on-chain state and promote config

## Deployment Skills

4 skills matching the 4 scripts. Each skill wraps its script + adds extra validation checks. Human drives the flow between steps.

**All skills are read-only. No skill will broadcast transactions.**

### Workflow

```
/deploy-prepare eth              ← VERSION check + prepare_deploy.js + forge build
        ↓ (human broadcasts deploy)
  [human runs: forge script DeployImpl ... --broadcast -vvvv]
        ↓
/deploy-verify eth               ← post_deploy.js + bytecode verify + source verify
        ↓ (if upgrading proxy)
/upgrade-prepare eth             ← validate staged impl + prepare_upgrade.js
        ↓ (human broadcasts upgrade)
  [human runs: forge script UpgradeProxy ... --broadcast -vvvv]
        ↓
/upgrade-verify eth              ← proxy state check + post_upgrade.js promote
```

Rollback uses the same flow: `/upgrade-prepare eth --rollback` → broadcast → `/upgrade-verify eth`

### Example

```
user:  /deploy-prepare eth
CC:    ✅ VERSION bumped  ✅ addresses prepared  ✅ compiled
       → forge script script/DeployImpl.s.sol:Deploy --rpc-url eth --broadcast -vvvv

user:  [broadcasts deploy]

user:  /deploy-verify eth
CC:    ✅ index.js updated  ✅ impl on-chain  ✅ source verified
       → /upgrade-prepare eth

user:  /upgrade-prepare eth
CC:    ✅ staged impl has bytecode  ✅ UpgradeProxy.s.sol addresses written
       → forge script script/UpgradeProxy.s.sol:UpgradeProxy --rpc-url eth --broadcast -vvvv

user:  [broadcasts upgrade]

user:  /upgrade-verify eth
CC:    Scenario: UPGRADE  ✅ proxy verified  ✅ config promoted
       implementation: 0xNEW, version: 1.2.0, history updated
```

### Skill Reference

| Skill | Script | Extra Checks |
|-------|--------|--------------|
| `/deploy-prepare <chain>` | `prepare_deploy.js` + `forge build` | VERSION bump check |
| `/deploy-verify <chain>` | `post_deploy.js` | bytecode on-chain, library bytecode, source verify, Quote.sol cleanup |
| `/upgrade-prepare <chain> [--rollback]` | `prepare_upgrade.js` | target impl bytecode on-chain, UpgradeProxy.s.sol diff |
| `/upgrade-verify <chain> [--check]` | `post_upgrade.js` | proxy slot, VERSION/owner/POOL_MANAGER state checks |

## Build & Test

```bash
forge build          # Compile all contracts
forge test           # Run tests
forge test -vvvv     # Verbose test output
```

Compiler: Solidity 0.8.17, optimizer 200 runs, via-ir enabled, evm_version cancun.
