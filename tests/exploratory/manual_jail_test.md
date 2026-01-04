# Manual Chroot Jail Test Procedure

This document outlines the steps to manually verify the `agt_agent_sandbox` chroot environment.

## Prerequisites
- `agt_agent_sandbox` VM running (`just lima-up`)
- `bun` installed in the VM
- `toybox` installed in `/usr/local/bin` in the VM

## 1. Deploy Jails
Run the deployment script to create `jail1` and `jail2` and populate them with binaries and libraries.

```bash
just lima-deploy-jails
```

**Verify**: Output should say "Jail jail1 ready" and "Jail jail2 ready".

## 2. Check Binaries
Verify that `bun` and `toybox` function inside the restricted environment.

```bash
# Check Bun
limactl shell agt_agent_sandbox sudo chroot /tmp/chroots/jail1 /bin/bun --version

# Check Toybox
limactl shell agt_agent_sandbox sudo chroot /tmp/chroots/jail1 /bin/toybox --version
```

**Verify**: Both commands should return version strings, not errors.

## 3. Verify Filesystem Isolation
Ensure that actions in one jail do not affect the other.

```bash
# Create file in Jail 1
limactl shell agt_agent_sandbox sudo chroot /tmp/chroots/jail1 /bin/toybox touch /tmp/isolation_test

# Verify it exists in Jail 1 physical path
limactl shell agt_agent_sandbox sudo ls -l /tmp/chroots/jail1/tmp/isolation_test

# Verify it is ABSENT from Jail 2 physical path
limactl shell agt_agent_sandbox sudo ls -l /tmp/chroots/jail2/tmp/isolation_test
```

**Verify**: The last command must fail with "No such file or directory".

## 4. Verify Parallel Execution & Concurrency
Ensure multiple agents can run simultaneously in different jails.

```bash
# Run the verification script
limactl shell agt_agent_sandbox < agt_agent_sandbox/parallel_verification.sh
```

**Verify**:
- Output should show "Jail1 PID" and "Jail2 PID".
- "Concurrency verified (Timestamps overlap)" should be printed at the end.

## 5. Cleanup (Optional)
To reset the jails:
```bash
just lima-deploy-jails
```
(The script deletes and recreates the directories).
