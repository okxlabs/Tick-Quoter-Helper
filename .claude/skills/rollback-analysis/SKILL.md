---
name: rollback-analysis
description: "Rollback decision support for Quote (QueryData). Checks current proxy state, identifies anomalies, lists rollback targets from implementationHistory, and outputs the rollback + verification commands. All checks are read-only."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: <chain>
---

# Rollback Analysis

Analyze rollback options for Quote on `$ARGUMENTS`.

## Instructions

You perform **read-only diagnostics** to help the user decide whether and how to rollback. You NEVER execute rollbacks or submit transactions. You analyze on-chain state, identify anomalies, and output the exact commands for the user.

## Diagnostic Steps

### 1. Parse Arguments

- Chain: `$ARGUMENTS`

### 2. Current On-Chain State

```bash
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <chain>
cast call <proxy> "VERSION()(string)" --rpc-url <chain>
cast call <proxy> "owner()(address)" --rpc-url <chain>
```

- [ ] Report current on-chain implementation address
- [ ] Report current on-chain VERSION
- [ ] Report owner address

### 3. Config State

Read `scripts/deployed/<chain>/index.js`:

Extract `proxy`, `proxyAdmin`, `implementation`, `stagedImplementation`, `version`, `implementationHistory`, `chainId`.

If `stagedImplementation` is present, report it as a pending upgrade that hasn't been applied yet.

### 4. Anomaly Detection

Compare on-chain vs config:

| Check | On-chain | Config | Status |
|-------|----------|--------|--------|
| Implementation | 0x... | 0x... | MATCH/MISMATCH |
| VERSION | X.Y.Z | X.Y.Z | MATCH/MISMATCH |

### 5. Implementation History

List all available rollback targets. For each, try to read VERSION:

```bash
cast call <history_address> "VERSION()(string)" --rpc-url <chain>
```

- [ ] History exists and has entries → PASS
- [ ] History empty → FAIL: "No rollback targets available"

### 6. Verify Rollback Target Exists On-Chain

```bash
cast code <rollback_target> --rpc-url <chain>
```

- [ ] Non-empty bytecode → PASS
- [ ] Empty → FAIL: "Rollback target contract not found"

## Output Format

```
══════════════════════════════════════════════════════════
  ROLLBACK ANALYSIS — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  Current On-Chain State
  ℹ️ INFO  Proxy:          0x...
  ℹ️ INFO  Implementation: 0x...
  ℹ️ INFO  VERSION:        X.Y.Z
  ℹ️ INFO  owner:          0x...

  Config State
  ℹ️ INFO  stagedImplementation: 0x... (or: not set)

  Anomaly Detection
  ❌ FAIL  VERSION mismatch: on-chain "1.2.0", config "1.1.0"
  (or)
  ✅ PASS  No anomalies detected

  Rollback Targets
  [0] 0xAAAA... — VERSION: 1.0.0
  [1] 0xBBBB... — VERSION: 1.1.0  ← recommended (most recent previous)

  Rollback Target Verification
  ✅ PASS  0xBBBB... exists on-chain with valid bytecode

══════════════════════════════════════════════════════════
  RECOMMENDATION
══════════════════════════════════════════════════════════

  To rollback to [1] 0xBBBB... (VERSION 1.1.0):

    PROXY=<proxy> PROXY_ADMIN=<proxyAdmin> \
      NEW_IMPLEMENTATION=<rollback_target> CHAIN_ID=<chainId> \
      forge script script/UpgradeProxy.s.sol:UpgradeProxy \
      --rpc-url <chain> --broadcast -vvvv

  To rollback to a different target (e.g. [0]):

    PROXY=<proxy> PROXY_ADMIN=<proxyAdmin> \
      NEW_IMPLEMENTATION=<history_0_address> CHAIN_ID=<chainId> \
      forge script script/UpgradeProxy.s.sol:UpgradeProxy \
      --rpc-url <chain> --broadcast -vvvv

  To verify after rollback:

    cast storage <proxy> \
      0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
      --rpc-url <chain>
    # Should contain: <rollback_target_address>

  Then promote config:
    /verify-state <chain>

══════════════════════════════════════════════════════════
```

IMPORTANT: Always fill in the actual addresses from config in the output commands. Do not use placeholders.

If no anomalies are detected, still show the history and commands but note: "No immediate rollback needed."
If history is empty, set FAIL and do NOT output rollback commands.
