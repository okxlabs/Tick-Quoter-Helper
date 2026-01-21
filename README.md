## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy Steps

**Manual Steps**

**1. Setup environment variables**

Fill in your values in `.env`:

```shell
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
ETH_RPC_URL=https://ethereum-rpc.publicnode.com
# ... other RPC URLs
```

**2. Prepare Quote.sol for target chain**

This script replaces the hardcoded addresses in `Quote.sol` with the correct ones for the target chain:

```shell
$ node scripts/prepare_deploy.js <chain>
```

**3. Deploy implementation contract**

```shell
$ forge script script/DeployImpl.s.sol:Deploy --rpc-url <chain> --broadcast -vvvv
```

**4. Update index.js and generate verify command**

```shell
$ node scripts/post_deploy.js <chain>
```

**5. Verify implementation contract**

Copy the generated verify command from step 4 and run it.

**6. Deploy proxy contract**

Copy the generated deploy proxy command from step 4 and run it.

**7. Update index.js with proxy addresses**

```shell
$ node scripts/post_deploy.js <chain>
```

### Deployed Addresses

See `scripts/deployed/<chain>/index.js` for deployed contract addresses on each chain.

### Upgrade Proxy

This repo uses **OpenZeppelin TransparentUpgradeableProxy + ProxyAdmin**. To upgrade, you only need:

- **proxy**
- **proxyAdmin**
- **new implementation**

These are recorded in `scripts/deployed/<chain>/index.js`.

**1. (Optional) Update `script/UpgradeProxy.s.sol` constants from config**

This will replace `PROXY` / `PROXY_ADMIN` / `NEW_IMPLEMENTATION` in `script/UpgradeProxy.s.sol` using the addresses in `scripts/deployed/<chain>/index.js`.

```shell
# Use implementation from index.js as NEW_IMPLEMENTATION
node scripts/sync_upgrade_constants.js <chain>

# Or explicitly set NEW_IMPLEMENTATION
node scripts/sync_upgrade_constants.js <chain> --new-impl 0xYourNewImplementation
```

**2. Run upgrade**

```shell
forge script script/UpgradeProxy.s.sol:UpgradeProxy --rpc-url $RPC_URL --broadcast -vvvv
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
