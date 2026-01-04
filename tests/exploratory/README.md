# Exploratory Manual Testing

This directory contains runbooks and procedures for manually verifying the `agt_agent_sandbox` capabilities.

## Test Runbooks

### 1. [Manual Jail Verification](manual_jail_test.md)
**Purpose**: Step-by-step guide to verify that the chroot jails are correctly deployed, isolated, and can run binaries like `bun` and `toybox`.
**Scope**:
- Check binary versions inside chroot.
- Verify filesystem isolation (file presence/absence).
- Verify parallel execution.

## Automated Verification
For quick verification, the project includes a helper script that automates the steps defined in the runbooks above:

```bash
# Run a full verify pass (Deploys unique jails + Runs parallel test)
just lima-verify-run
```

## Reports
Test reports are generated in the `.tmp/` directory at the project root.
