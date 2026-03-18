---
name: deploy-verify
description: "Post-deployment verification: post_deploy.js, on-chain bytecode check, source verify command, Quote.sol cleanup reminder. Never broadcasts."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "<chain>"
---

# Deploy Verify

Post-deployment verification for `$ARGUMENTS`.

## Instructions

You verify a deployment that the user has already broadcast. You NEVER broadcast transactions.

## Workflow

### 1. Parse Arguments

- **chain** (required)
- If missing → error and stop.

### 2. Run post_deploy.js

```bash
node scripts/post_deploy.js <chain>
```

- Success → PASS, note the implementation address and verify command from output
- Failure → FAIL, stop

### 3. On-Chain Bytecode Check

Using the implementation address from step 2 (read from `scripts/deployed/<chain>/index.js` — use `stagedImplementation` if set, otherwise `implementation`):

```bash
cast code <impl_address> --rpc-url <chain>
```

- Non-empty → PASS: "Implementation bytecode exists (N bytes)"
- Empty → FAIL

### 4. Library Bytecode Check

For each library in `scripts/deployed/<chain>/index.js` `libraries` object:

```bash
cast code <library_address> --rpc-url <chain>
```

- All have code → PASS: "Libraries: N/N have bytecode"
- Any missing → WARN

### 5. Source Verification

Extract the `forge verify-contract` command from post_deploy.js output (step 2).

IMPORTANT: Replace `$ETHERSCAN_API_KEY` with `"$(grep '^ETHERSCAN_API_KEY' .env | cut -d= -f2)"` to load the key from .env.

- Success → PASS
- Failure → WARN, output command for manual retry

### 6. Quote.sol Cleanup

```bash
git diff src/Quote.sol
```

- Modified → WARN: "Quote.sol still modified — run: git checkout -- src/Quote.sol"
- Clean → PASS

### 7. Proxy State (Informational)

Read proxy state from config and on-chain:

```bash
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <chain>
```

Report:
- On-chain implementation
- `stagedImplementation` from config (pending upgrade target)
- `implementation` from config (current active)

### 8. Output

```
══════════════════════════════════════════════════════════
  DEPLOY VERIFY — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  ✅ PASS  post_deploy.js: index.js updated
  ✅ PASS  Implementation bytecode: N bytes
  ✅ PASS  Libraries: 9/9 have bytecode
  ✅ PASS  Source verified
  ⚠️ WARN  Quote.sol still modified

  Proxy State
  ℹ️ INFO  On-chain impl:          0x...
  ℹ️ INFO  stagedImplementation:   0x... (pending)
  ℹ️ INFO  implementation:         0x... (current)

══════════════════════════════════════════════════════════
  RESULT: VERIFIED / HAS ISSUES
══════════════════════════════════════════════════════════

  Next step (if upgrading proxy):
    /upgrade-prepare <chain>

══════════════════════════════════════════════════════════
```
