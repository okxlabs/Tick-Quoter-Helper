---
name: verify-state
description: "Post-upgrade/rollback state verification and config promotion. Reads on-chain state via cast, auto-detects upgrade vs rollback vs no-change, and promotes stagedImplementation via promote_config.js. All checks are read-only except the config promotion."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: <chain>
---

# Verify State

Post-upgrade/rollback state verification and config promotion for Quote on `$ARGUMENTS`.

## Instructions

You verify on-chain state after the user has executed an upgrade or rollback, then promote the config so it reflects reality. You NEVER broadcast transactions.

## Workflow

### 1. Parse Arguments

- Chain: `$ARGUMENTS` (must be a valid chain from `scripts/lib/chains.js`)
- If missing or invalid, output an error and stop.

### 2. Load Config (Pre-Promotion)

Read `scripts/deployed/<chain>/index.js`:

Extract and report:
- `proxy`
- `proxyAdmin`
- `implementation` (current config)
- `stagedImplementation` (pending upgrade target, if present)
- `implementationHistory` (list with count)
- `version`

### 3. On-Chain Validation (Inline)

Run these `cast` commands directly and report PASS/FAIL for each:

**Implementation slot:**
```bash
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <chain>
```
- Extract address from last 20 bytes of the 32-byte slot value
- Report the on-chain implementation address

**Admin slot:**
```bash
cast storage <proxy> 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url <chain>
```
- Extract address from last 20 bytes
- Compare against `config.proxyAdmin` — report PASS if match, FAIL if mismatch

**VERSION:**
```bash
cast call <proxy> "VERSION()(string)" --rpc-url <chain>
```
- Report on-chain VERSION value

**owner:**
```bash
cast call <proxy> "owner()(address)" --rpc-url <chain>
```
- PASS if non-zero address, FAIL if zero or call failed

**POOL_MANAGER (if applicable):**
Only if `uniswapV4.poolManager` exists in config:
```bash
cast call <proxy> "POOL_MANAGER()(address)" --rpc-url <chain>
```
- Compare against `config.uniswapV4.poolManager` — report PASS if match, FAIL if mismatch

### 4. Auto-Detect Scenario

Compare on-chain implementation with config:

| Scenario | Condition | Action |
|----------|-----------|--------|
| **Upgrade** | on-chain impl == `stagedImplementation` | Promote staged -> implementation |
| **Rollback** | on-chain impl found in `implementationHistory` | Set implementation to match on-chain |
| **No change** | on-chain impl == `implementation` | Report, no action |
| **Unknown** | on-chain impl not in config or history | Error out |

Report the detected scenario before running promotion.

### 5. Run Promotion

```bash
node scripts/promote_config.js <chain>
```

- [ ] Script exits 0
- [ ] If FAIL -> report errors and stop

### 6. Verify Promotion

Re-read `scripts/deployed/<chain>/index.js` (clear require cache or re-read file):

- [ ] `implementation` matches on-chain
- [ ] `stagedImplementation` is absent (deleted)
- [ ] `version` matches on-chain VERSION
- [ ] `implementationHistory` updated correctly

### 7. Summary

## Output Format

```
══════════════════════════════════════════════════════════
  VERIFY STATE — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  Pre-Promotion Config
  ℹ️ INFO  implementation:       0xCURRENT...
  ℹ️ INFO  stagedImplementation: 0xSTAGED... (or: not set)
  ℹ️ INFO  version:              1.1.0
  ℹ️ INFO  history:              N entries

  On-Chain State
  ✅ PASS  Implementation: 0x...
  ✅ PASS  Admin:          0x...
  ✅ PASS  VERSION:        1.2.0
  ✅ PASS  owner:          0x...
  ✅ PASS  POOL_MANAGER:   0x...

  Detection
  ℹ️ INFO  Scenario: UPGRADE (on-chain matches stagedImplementation)

  Promotion
  ✅ PASS  promote_config.js succeeded
  ✅ PASS  implementation updated: 0xSTAGED...
  ✅ PASS  stagedImplementation removed
  ✅ PASS  version updated: 1.2.0
  ✅ PASS  history: N+1 entries (previous impl archived)

══════════════════════════════════════════════════════════
  RESULT: STATE VERIFIED / HAS ISSUES
══════════════════════════════════════════════════════════
```

If scenario is "No change", skip the Promotion section and report:
```
  Detection
  ℹ️ INFO  Scenario: NO CHANGE (on-chain matches config.implementation)
  ℹ️ INFO  No promotion needed
```

IMPORTANT: Always use actual addresses and values from config/on-chain reads. Do not use placeholders.
