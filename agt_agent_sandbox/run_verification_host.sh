#!/bin/bash
set -e

# Generate unique ID for this run
RUN_ID="run-$(date +%Y%m%d-%H%M%S)"
JAIL1="${RUN_ID}-a"
JAIL2="${RUN_ID}-b"

echo "=============================================="
echo "Starting Verification Run: $RUN_ID"
echo "Jails: $JAIL1, $JAIL2"
echo "=============================================="

# 1. Deploy Jails (Runs script inside VM)
echo ">>> Deploying Jails..."
limactl copy agt_agent_sandbox/setup_bun_chroot.sh agt_agent_sandbox:/tmp/setup_bun_chroot.sh
limactl shell agt_agent_sandbox chmod +x /tmp/setup_bun_chroot.sh
limactl shell agt_agent_sandbox /tmp/setup_bun_chroot.sh "$JAIL1" "$JAIL2"

# 2. Verify (Runs script inside VM)
echo ">>> Verifying Concurrency & Isolation..."
limactl copy agt_agent_sandbox/verify_jails.sh agt_agent_sandbox:/tmp/verify_jails.sh
limactl shell agt_agent_sandbox chmod +x /tmp/verify_jails.sh
limactl shell agt_agent_sandbox /tmp/verify_jails.sh "$JAIL1" "$JAIL2"

echo "=============================================="
echo "Run $RUN_ID Completed Successfully"
echo "=============================================="
