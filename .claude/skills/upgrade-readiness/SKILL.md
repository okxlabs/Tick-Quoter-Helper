---
name: upgrade-readiness
description: "Pre-upgrade state confirmation before pointing a Quote proxy to a new implementation. Verifies the new impl is deployed, checks on-chain proxy state, and outputs the upgrade + verification commands. All checks are read-only."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: <chain>
---

# Upgrade Readiness Check

Verify upgrade readiness for Quote on `$ARGUMENTS`.

## Instructions

You perform **read-only checks** to confirm that a proxy upgrade is safe to execute. You NEVER execute upgrades or submit transactions. Your job is to verify preconditions and output the exact commands for the user.

## Checklist

### 1. Parse Arguments

- Chain: `$ARGUMENTS`

### 2. Load Config

Read `scripts/deployed/<chain>/index.js`:

Extract `proxy`, `proxyAdmin`, `implementation`, `stagedImplementation`, `implementationHistory`, `chainId`.

The upgrade target is `stagedImplementation` (preferred) or `implementation` (fallback).

- [ ] Proxy address exists
- [ ] ProxyAdmin address exists
- [ ] Target implementation address exists (`stagedImplementation` or `implementation`)

### 3. Current On-Chain State

Read the EIP-1967 implementation slot:

```bash
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <chain>
```

Extract the implementation address (last 40 hex chars).

- [ ] Slot is readable
- [ ] Report: current on-chain implementation address
- [ ] Compare with config's target implementation:
  - If same → WARN: "Proxy already points to this implementation — nothing to upgrade"
  - If different → PASS: "Upgrade needed"

### 4. Current On-Chain VERSION

```bash
cast call <proxy> "VERSION()(string)" --rpc-url <chain>
```

- [ ] Report current VERSION

### 5. New Implementation Exists On-Chain

```bash
cast code <target_implementation> --rpc-url <chain>
```

- [ ] Non-empty bytecode → PASS
- [ ] Empty bytecode → FAIL: "Target implementation not found on-chain"

### 6. New Implementation VERSION

```bash
cast call <target_implementation> "VERSION()(string)" --rpc-url <chain>
```

- [ ] VERSION readable → Report value
- [ ] Compare with current proxy VERSION:
  - If higher → PASS: "VERSION will upgrade from X to Y"
  - If same → WARN: "Same VERSION — is this intentional?"
  - If lower → WARN: "Looks like a rollback, use /rollback-analysis instead"

### 7. Implementation History

- [ ] Report history length: "N previous implementations available for rollback"

## Output Format

```
══════════════════════════════════════════════════════════
  UPGRADE READINESS — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  Config
  ✅ PASS  Proxy: 0x...
  ✅ PASS  ProxyAdmin: 0x...
  ✅ PASS  Target impl: 0x...

  On-Chain State
  ✅ PASS  Current impl: 0x... (different from target — upgrade needed)
  ✅ PASS  Current VERSION: 1.1.0

  Target Implementation
  ✅ PASS  Target impl deployed on-chain
  ✅ PASS  Target VERSION: 1.2.0 (upgrade from 1.1.0)

  Rollback Safety
  ✅ PASS  implementationHistory has N entries

  Before / After
  ──────────────────────────────────────
  Current Impl:    0xOLD...
  Current VERSION: 1.1.0
  ──────────────────────────────────────
  Target Impl:     0xNEW...
  Target VERSION:  1.2.0
  ──────────────────────────────────────

══════════════════════════════════════════════════════════
  RESULT: READY TO UPGRADE / NOT READY
══════════════════════════════════════════════════════════

  Dry-run (simulate without broadcasting):

    PROXY=<proxy> PROXY_ADMIN=<proxyAdmin> \
      NEW_IMPLEMENTATION=<target_impl> CHAIN_ID=<chainId> \
      forge script script/UpgradeProxy.s.sol:UpgradeProxy \
      --rpc-url <chain> -vvvv

  Broadcast (execute on-chain):

    PROXY=<proxy> PROXY_ADMIN=<proxyAdmin> \
      NEW_IMPLEMENTATION=<target_impl> CHAIN_ID=<chainId> \
      forge script script/UpgradeProxy.s.sol:UpgradeProxy \
      --rpc-url <chain> --broadcast -vvvv

  To verify after upgrade:

    cast storage <proxy> \
      0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
      --rpc-url <chain>
    # Should contain: <target_impl_address>

  Then promote config:
    /verify-state <chain>

══════════════════════════════════════════════════════════
```

IMPORTANT: Always fill in the actual addresses from config in the output commands. Do not use placeholders.

If any check is FAIL, set result to NOT READY and do NOT output the upgrade command.
