---
name: upgrade-verify
description: "Post-upgrade verification: check proxy on-chain state, run post_upgrade.js to promote config. Never broadcasts."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "<chain> [--check]"
---

# Upgrade Verify

Post-upgrade verification for `$ARGUMENTS`.

## Instructions

You verify an upgrade/rollback that the user has already broadcast. You NEVER broadcast transactions.

## Workflow

### 1. Parse Arguments

- **chain** (required)
- **--check** (optional): read-only mode, don't write config
- If chain missing → error and stop.

### 2. UpgradeProxy.s.sol Cleanup Check

```bash
git diff script/UpgradeProxy.s.sol
```

- Modified → WARN: "UpgradeProxy.s.sol still modified — run: git checkout -- script/UpgradeProxy.s.sol"
- Clean → PASS

### 3. Pre-flight: Proxy State

Read proxy on-chain implementation:

```bash
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <chain>
```

Read `scripts/deployed/<chain>/index.js` and compare:
- On-chain impl vs `implementation` (current)
- On-chain impl vs `stagedImplementation` (pending)
- On-chain impl vs `implementationHistory` entries

Report detected scenario: UPGRADE / ROLLBACK / NO-CHANGE / UNKNOWN

### 4. State Checks

Call key view functions via proxy to verify the upgrade didn't break state:

```bash
cast call <proxy> "VERSION()(string)" --rpc-url <chain>
cast call <proxy> "owner()(address)" --rpc-url <chain>
cast call <proxy> "POOL_MANAGER()(address)" --rpc-url <chain>
```

- VERSION returns valid string → PASS
- owner returns non-zero → PASS
- POOL_MANAGER matches config → PASS (if config has uniswapV4.poolManager)

### 5. Run post_upgrade.js

```bash
node scripts/post_upgrade.js <chain> [--check]
```

This auto-detects the scenario and promotes config (or reports what would change in --check mode).

- Success → PASS
- Failure → FAIL

### 6. Verify Config Updated

Re-read `scripts/deployed/<chain>/index.js`:
- `stagedImplementation` removed (upgrade) → PASS
- `implementation` updated → PASS
- `implementationHistory` has new entry → PASS
- `version` updated → PASS

### 7. Output

```
══════════════════════════════════════════════════════════
  UPGRADE VERIFY — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  Scenario: UPGRADE / ROLLBACK / NO-CHANGE

  ✅ PASS  UpgradeProxy.s.sol clean
  ✅ PASS  On-chain impl matches stagedImplementation
  ✅ PASS  VERSION: "1.2.0"
  ✅ PASS  owner: 0x...
  ✅ PASS  POOL_MANAGER: 0x...
  ✅ PASS  Config promoted: implementation updated, history archived

  Summary:
    implementation: 0xNEW
    version: 1.2.0
    history: N entries

══════════════════════════════════════════════════════════
  RESULT: VERIFIED / HAS ISSUES
══════════════════════════════════════════════════════════
```
