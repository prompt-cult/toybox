#!/bin/sh
set -eu

VM_NAME="${1:-agt_agent_sandbox}"

if ! command -v limactl >/dev/null 2>&1; then
    echo "Error: limactl not found. Install Lima first." >&2
    exit 1
fi

if ! limactl list --format '{{.Name}}' | grep -qx "$VM_NAME"; then
    echo "Error: VM '${VM_NAME}' does not exist." >&2
    exit 1
fi

echo "Stopping VM '${VM_NAME}'..."
limactl stop "$VM_NAME"
echo "VM '${VM_NAME}' stopped."
