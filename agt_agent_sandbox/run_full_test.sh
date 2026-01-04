#!/bin/sh
set -e

VM="agt_agent_sandbox"
REMOTE_USER="consensussolutions.linux"
REMOTE_HOME="/home/${REMOTE_USER}"

echo ">>> Deploying Test Assets..."
limactl copy ./agt_agent_sandbox/oc_manager.py "${VM}:${REMOTE_HOME}/"

# Create a test prompt
echo "# Test Prompt" > /tmp/test_prompt.md
echo "Task: Validate Isolation" >> /tmp/test_prompt.md
limactl copy /tmp/test_prompt.md "${VM}:${REMOTE_HOME}/"

echo ">>> Running Orchestrator inside VM..."
limactl shell "$VM" python3 oc_manager.py test_prompt.md --jails jail1 jail2
