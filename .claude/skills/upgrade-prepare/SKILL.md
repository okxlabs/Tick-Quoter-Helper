---
name: upgrade-prepare
description: "Pre-upgrade preparation: validate staged impl on-chain, run prepare_upgrade.js to write addresses into UpgradeProxy.s.sol. Never broadcasts."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "<chain> [--rollback [--to <N>]]"
---

# Upgrade Prepare

Pre-upgrade preparation for `$ARGUMENTS`.

## Instructions

You prepare an upgrade or rollback. You NEVER broadcast transactions.

## Workflow

### 1. Parse Arguments

- **chain** (required)
- **--rollback** (optional): rollback mode
- **--to N** (optional): specific history index
- If chain missing → error and stop.

### 2. Validate Target Implementation On-Chain

Read `scripts/deployed/<chain>/index.js`:
- Upgrade mode: use `stagedImplementation`
- Rollback mode: use `implementationHistory[N]` (last entry by default)

Check target has bytecode on-chain:

```bash
cast code <target_impl> --rpc-url <chain>
```

- Non-empty → PASS
- Empty → FAIL: "Target implementation has no code on-chain"

### 3. Run prepare_upgrade.js

```bash
node scripts/prepare_upgrade.js <chain> [--rollback [--to <N>]]
```

This writes addresses into `script/UpgradeProxy.s.sol` and outputs the forge commands.

- Success → PASS
- Failure → FAIL, stop

### 4. Verify UpgradeProxy.s.sol Was Modified

```bash
git diff script/UpgradeProxy.s.sol
```

- Has changes → PASS: addresses written
- No changes → FAIL: prepare_upgrade.js didn't modify the file

### 5. Output

```
══════════════════════════════════════════════════════════
  UPGRADE PREPARE — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  Mode: UPGRADE / ROLLBACK

  ✅ PASS  Target impl has bytecode: N bytes
  ✅ PASS  UpgradeProxy.s.sol addresses written

  Addresses:
    Proxy:          0x...
    ProxyAdmin:     0x...
    Current impl:   0x...
    Target impl:    0x...

══════════════════════════════════════════════════════════
  RESULT: READY / NOT READY
══════════════════════════════════════════════════════════

  Dry-run first:
    forge script script/UpgradeProxy.s.sol:UpgradeProxy --rpc-url <chain> -vvvv

  Then broadcast:
    forge script script/UpgradeProxy.s.sol:UpgradeProxy --rpc-url <chain> --broadcast -vvvv

  After broadcast:
    git checkout -- script/UpgradeProxy.s.sol
    /upgrade-verify <chain>

══════════════════════════════════════════════════════════
```
