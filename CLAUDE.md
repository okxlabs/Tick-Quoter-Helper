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

The `version` field tracks the contract VERSION() constant. `QueryData` exposes `string public constant VERSION`. The `promote_config.js` script reads VERSION() on-chain and writes it back to index.js.

### Staged Implementation Workflow

When `post_deploy.js` extracts a new implementation address, it writes to `stagedImplementation` instead of overwriting `implementation`. This keeps `implementation` reflecting the actual on-chain proxy target until the upgrade is confirmed:

1. **Deploy impl** → `post_deploy.js` sets `stagedImplementation` (first-time deploy writes directly to `implementation`)
2. **Upgrade proxy** → human executes upgrade transaction
3. **Promote config** → `promote_config.js` (or `/verify-state <chain>`) detects the upgrade, moves `stagedImplementation` → `implementation`, archives the old impl in `implementationHistory`, and updates `version`

The script also handles rollback detection: if the on-chain impl matches a `implementationHistory` entry, it promotes accordingly.

### Implementation History

When upgrading or rolling back, the previous implementation address is automatically appended to `implementationHistory`. This enables rollback to any prior version. History is ordered oldest → newest. The `--to <N>` flag selects a specific index (0-based); default is the last entry (most recent previous version).

### Environment Variables

Required in `.env` (never committed):
- `PRIVATE_KEY` — deployer wallet private key
- `ETHERSCAN_API_KEY` — for source code verification
- `<CHAIN>_RPC_URL` — per-chain RPC endpoints (e.g., `ETH_RPC_URL`, `BASE_RPC_URL`)

## Key Scripts

| Script | Purpose |
|--------|---------|
| `scripts/prepare_deploy.js <chain>` | Writes chain addresses into `src/Quote.sol` constants |
| `scripts/post_deploy.js <chain>` | Reads broadcast output → writes `stagedImplementation` to `deployed/<chain>/index.js` |
| `scripts/promote_config.js <chain>` | Read on-chain state via `cast`; promote staged config; `--check` for read-only |
| `scripts/lib/chains.js` | Shared chain config (CHAINS, aliases, library mapping) |

## Forge Scripts

| Script | Purpose |
|--------|---------|
| `script/DeployImpl.s.sol:Deploy` | Deploy QueryData implementation |
| `script/DeployProxy.s.sol:DeployProxy` | Deploy TransparentProxy + ProxyAdmin |
| `script/UpgradeProxy.s.sol:UpgradeProxy` | Upgrade proxy to new implementation (env: PROXY, PROXY_ADMIN, NEW_IMPLEMENTATION) |

## Safety Rules

1. **Always dry-run before broadcast** — `forge script ... -vvvv` (no `--broadcast`) first
2. **Validate after every deployment** — `node scripts/promote_config.js <chain> --check`
3. **Never commit `.env`** — it contains private keys
4. **Restore Quote.sol after deploy** — `git checkout -- src/Quote.sol` (prepare_deploy modifies it temporarily)
5. **Check chain ID** — UpgradeProxy.s.sol supports optional `CHAIN_ID` env var for safety
6. **Update VERSION on upgrade** — bump the `VERSION` constant in `src/Quote.sol` before deploying a new implementation
7. **Deploy and upgrade are separate steps** — use `deploy-impl` to deploy implementation + verify source, then `upgrade` to point proxy to new impl. Never bundle them into one operation
8. **Validate after upgrade/rollback** — use `promote_config.js` (or `/verify-state <chain>`) to confirm on-chain state and promote config

## Deployment Skills

Skills codify the team's deployment workflow into reusable CC-assisted checkpoints. Each skill covers one step — the human drives the flow between steps, CC assists quality within each step.

**All skills are read-only except dry-run. No skill will broadcast transactions.**

### Workflow

```
/deploy-prepare eth              ← VERSION check + prepare_deploy + forge build
        ↓ (human reviews, broadcasts)
  [human runs: forge script ... --broadcast -vvvv]
        ↓ (broadcast completes)
/verify-contract eth             ← post_deploy + on-chain verify + source verify
        ↓ (if upgrading proxy)
/upgrade-readiness eth           ← Check on-chain state, output forge script command
        ↓ (human reviews, runs upgrade)
  [human runs: PROXY=... forge script UpgradeProxy ... --broadcast -vvvv]
        ↓ (upgrade completes)
/verify-state eth                ← Verify on-chain state + promote config
        ↓ (if issues detected)
/rollback-analysis eth           ← Diagnose anomaly, output forge script command
        ↓ (human reviews, runs rollback)
  [human runs: PROXY=... forge script UpgradeProxy ... --broadcast -vvvv]
        ↓ (rollback completes)
/verify-state eth                ← Verify on-chain state + promote config
```

### Example: Deploy Quote Impl to ETH and Upgrade

```
user:  /deploy-prepare eth
CC:    ✅ VERSION 1.2.0 bumped  ✅ addresses prepared  ✅ compiled
       → forge script script/DeployImpl.s.sol:Deploy --rpc-url eth --broadcast -vvvv

user:  [runs broadcast command]

user:  /verify-contract eth
CC:    ✅ index.js updated (stagedImplementation set)  ✅ impl on-chain  ✅ source verified
       → next: /upgrade-readiness eth

user:  /upgrade-readiness eth
CC:    current impl 0xOLD → target 0xNEW, VERSION 1.1.0 → 1.2.0
       → PROXY=... PROXY_ADMIN=... NEW_IMPLEMENTATION=... forge script ...

user:  [runs upgrade command]

user:  /verify-state eth
CC:    ✅ on-chain matches stagedImplementation  ✅ config promoted
       implementation: 0xNEW, version: 1.2.0, history updated
```

Human drives every decision. CC assists quality at each checkpoint. No skill will broadcast transactions.

### Skill Reference

| Skill | Purpose | Allowed Actions |
|-------|---------|-----------------|
| `/deploy-prepare <chain>` | VERSION check + prepare addresses + compile | `prepare_deploy.js`, `forge build`, read files |
| `/verify-contract <chain>` | Post-broadcast: extract addresses + verify | `post_deploy.js`, `cast`, `forge verify-contract` |
| `/upgrade-readiness <chain>` | Pre-upgrade state confirmation | `cast call/storage`, read config |
| `/verify-state <chain>` | Post-upgrade/rollback: verify + promote config | `promote_config.js`, `cast`, read config |
| `/rollback-analysis <chain>` | Rollback decision support | `cast call/storage`, read history |

## Build & Test

```bash
forge build          # Compile all contracts
forge test           # Run tests
forge test -vvvv     # Verbose test output
```

Compiler: Solidity 0.8.17, optimizer 200 runs, via-ir enabled, evm_version cancun.
