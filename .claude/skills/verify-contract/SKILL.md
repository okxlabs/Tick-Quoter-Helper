---
name: verify-contract
description: "Post-broadcast verification for Quote (QueryData). Extracts addresses from broadcast artifacts, updates index.js, verifies implementation on-chain, and checks proxy state. All checks are read-only except index.js update."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: <chain>
---

# Verify Contract

Post-broadcast verification for Quote on `$ARGUMENTS`.

## Instructions

You verify a deployment that the user has already broadcast. You NEVER broadcast transactions.

## Workflow

### 1. Parse Arguments

- Chain: `$ARGUMENTS` (must be a valid chain from `scripts/lib/chains.js`)
- If missing or invalid, output an error and stop.

### 2. Extract Addresses (post_deploy.js)

Run post_deploy.js to read broadcast artifacts and update index.js:

```bash
node scripts/post_deploy.js <chain>
```

- [ ] Script runs successfully
- [ ] Implementation address extracted
- [ ] index.js updated with new addresses
- [ ] If implementation not found → FAIL: "No broadcast artifacts found — did the deployment succeed?"

### 3. Implementation On-Chain

Verify the new implementation contract exists:

```bash
cast code <implementation_address> --rpc-url <chain>
```

- [ ] Returns non-empty bytecode (not `0x`)
- [ ] If empty → FAIL: "Implementation not found on-chain"

### 4. Library Verification

For each library in `config.libraries`, check it exists on-chain:

```bash
cast code <library_address> --rpc-url <chain>
```

- [ ] Each library has non-empty bytecode

Additionally, check library addresses appear in the implementation bytecode:

- [ ] All library addresses found in implementation bytecode → PASS
- [ ] Missing library address → WARN: "Library X may not be linked"

### 5. Source Verification

Extract the `forge verify-contract` command from the post_deploy.js output (step 2) and execute it.

IMPORTANT: Replace `$ETHERSCAN_API_KEY` with `"$(grep '^ETHERSCAN_API_KEY' .env | cut -d= -f2)"` to load the key from .env without exposing other secrets like PRIVATE_KEY.

- [ ] If verification succeeds → PASS
- [ ] If verification fails → WARN and output the command for the user to retry manually

### 6. Quote.sol State

```bash
git diff src/Quote.sol
```

- [ ] No changes → Remind user: "Quote.sol still has chain addresses. Run: git checkout -- src/Quote.sol"
- [ ] Clean → PASS

### 7. Proxy State (Informational)

Read current proxy state:

```bash
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <chain>
```

- [ ] Report current on-chain implementation
- [ ] Report `stagedImplementation` from config (the pending upgrade target), or note "not set"
- [ ] Report `implementation` from config (the current/active impl)
- [ ] If on-chain differs from config and `stagedImplementation` is set → "Proxy NOT upgraded yet. To upgrade: /upgrade-readiness <chain>"
- [ ] If on-chain matches `stagedImplementation` → "Proxy already upgraded. Run /verify-state <chain> to promote config"
- [ ] If on-chain matches `implementation` and no `stagedImplementation` → "Proxy up to date"

## Output Format

```
══════════════════════════════════════════════════════════
  VERIFY CONTRACT — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  Post-Deploy
  ✅ PASS  post_deploy.js: index.js updated
  ✅ PASS  Implementation: 0x...

  On-Chain Verification
  ✅ PASS  Implementation bytecode exists
  ✅ PASS  Libraries on-chain: 9/9 have bytecode

  Source Verification
  ✅ PASS  Source code verified on etherscan

  Quote.sol State
  ⚠️ WARN  Quote.sol still modified — run: git checkout -- src/Quote.sol

  Proxy State
  ℹ️ INFO  Proxy on-chain impl:    0x...
  ℹ️ INFO  stagedImplementation:   0x... (pending upgrade target)
  ℹ️ INFO  config.implementation:  0x... (current active)

══════════════════════════════════════════════════════════
  RESULT: DEPLOYMENT VERIFIED / HAS ISSUES
══════════════════════════════════════════════════════════
  Next step (if upgrading proxy):
    /upgrade-readiness <chain>
══════════════════════════════════════════════════════════
```
