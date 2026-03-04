---
name: deploy-prepare
description: "Pre-deployment preparation for Quote (QueryData). Checks VERSION bump, deployment state, runs prepare_deploy.js to replace addresses, and compiles. Never broadcasts transactions."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
argument-hint: <chain>
---

# Deploy Prepare

Pre-deployment preparation for Quote on `$ARGUMENTS`.

## Instructions

You perform pre-deployment validation and preparation. You NEVER broadcast transactions.

## Workflow

### 1. Parse Arguments

- Chain: `$ARGUMENTS` (must be a valid chain from `scripts/lib/chains.js`)
- If missing or invalid, output an error and stop.

### 2. VERSION Check

Read `src/Quote.sol`, find `string public constant VERSION = "..."`.
Read `scripts/deployed/<chain>/index.js`, find `version` field.

- [ ] VERSION constant exists
- [ ] If they are the same → WARN: "VERSION not bumped — are you redeploying the same version?"
- [ ] If source VERSION > index.js version → PASS: "VERSION bumped to X.Y.Z"

### 3. Deployment State

Read `scripts/deployed/<chain>/index.js`:

- [ ] Report current `proxy`, `proxyAdmin`, `implementation`
- [ ] If proxy exists → "This is an upgrade deployment (existing proxy found)"
- [ ] If no proxy → "This is a first-time deployment"
- [ ] Report `implementationHistory` length (rollback targets available)

### 4. Prepare Quote.sol

```bash
node scripts/prepare_deploy.js <chain>
```

- [ ] Script runs successfully
- [ ] Report the addresses written into Quote.sol

### 5. Compile

```bash
forge build
```

- [ ] Compilation succeeds without errors

## Output Format

```
══════════════════════════════════════════════════════════
  DEPLOY PREPARE — Quote on <CHAIN>
══════════════════════════════════════════════════════════

  VERSION
  ✅ PASS  VERSION: 1.2.0 (bumped from 1.1.0)

  Deployment State
  ℹ️ INFO  Proxy: 0x... (upgrade deployment)
  ℹ️ INFO  Current impl: 0x...
  ℹ️ INFO  History: 2 previous implementations

  Prepare
  ✅ PASS  Quote.sol addresses updated for <CHAIN>
  ✅ PASS  forge build: compiled successfully

══════════════════════════════════════════════════════════
  RESULT: READY / NOT READY
══════════════════════════════════════════════════════════

  To deploy, run:

    forge script script/DeployImpl.s.sol:Deploy \
      --rpc-url <chain> --broadcast -vvvv

  After broadcast completes:
    /verify-contract <chain>

══════════════════════════════════════════════════════════
```

If VERSION is not bumped, include a warning but do NOT block.
If compilation fails, set result to NOT READY.
