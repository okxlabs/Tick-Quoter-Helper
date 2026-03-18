# Tick-Quoter-Helper

On-chain quoter contracts for DEX aggregation. Provides batch query, storage decoding, and compact encoding for tick-based DEX liquidity data.

## Build & Test

```shell
forge build
forge test
forge test -vvvv    # verbose
```

## Deploy Steps

### 1. Setup environment variables

Fill in `.env` (never committed):

```shell
ETHERSCAN_API_KEY=your_etherscan_api_key
ETH_RPC_URL=https://...
BASE_RPC_URL=https://...
# ... other chain RPC URLs
```

### 2. Prepare Quote.sol for target chain

Replaces hardcoded addresses in `Quote.sol` with the correct ones for the target chain:

```shell
node scripts/prepare_deploy.js <chain>
```

### 3. Deploy implementation contract

```shell
forge script script/DeployImpl.s.sol:Deploy --rpc-url <chain> --broadcast -vvvv
```

### 4. Post-deploy: update index.js and verify

```shell
node scripts/post_deploy.js <chain>
```

Copy the generated verify command from the output and run it. Then restore Quote.sol:

```shell
git checkout -- src/Quote.sol
```

### 5. Deploy proxy (first-time only)

Copy the generated deploy proxy command from step 4 and run it, then run `post_deploy.js` again to record proxy addresses.

## Upgrade Proxy

Uses OpenZeppelin TransparentUpgradeableProxy + ProxyAdmin.

### 1. Generate upgrade command

Reads `proxy`, `proxyAdmin`, `stagedImplementation` from `scripts/deployed/<chain>/index.js`:

```shell
node scripts/prepare_upgrade.js <chain>
```

### 2. Dry-run, then broadcast

Copy and run the dry-run command from the output first, then the broadcast command.

### 3. Promote config

```shell
node scripts/post_upgrade.js <chain>
```

## Rollback

Same script, with `--rollback` flag:

```shell
# Rollback to the most recent previous implementation
node scripts/prepare_upgrade.js <chain> --rollback

# Rollback to a specific history entry (0-based index)
node scripts/prepare_upgrade.js <chain> --rollback --to <N>
```

Then dry-run, broadcast, and promote:

```shell
node scripts/post_upgrade.js <chain>
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/prepare_deploy.js <chain>` | Write chain addresses into `src/Quote.sol` constants |
| `scripts/post_deploy.js <chain>` | Read broadcast output, update `deployed/<chain>/index.js` |
| `scripts/prepare_upgrade.js <chain>` | Read index.js, output upgrade/rollback forge command |
| `scripts/post_upgrade.js <chain>` | Read on-chain state, promote config in index.js |

## Deployed Addresses

See `scripts/deployed/<chain>/index.js` for deployed contract addresses on each chain.
