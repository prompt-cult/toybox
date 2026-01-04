#!/bin/sh
set -eu

OLD_VM="agt_agent_sandbox"
NEW_VM="${1:-}"

if [ -z "$NEW_VM" ]; then
    echo "Usage: $0 <new_vm_name>" >&2
    exit 1
fi

if ! command -v limactl >/dev/null 2>&1; then
    echo "Error: limactl not found." >&2
    exit 1
fi

if ! limactl list --format '{{.Name}}' | grep -qx "$OLD_VM"; then
    echo "Error: Source VM '${OLD_VM}' does not exist." >&2
    exit 1
fi

STATUS=$(limactl list --format '{{.Name}} {{.Status}}' | grep "^${OLD_VM} " | awk '{print $2}')

if [ "$STATUS" = "Running" ]; then
    echo "Instance '${OLD_VM}' is running. Stopping it before cloning..."
    limactl stop "$OLD_VM"
fi

echo "Cloning '${OLD_VM}' to '${NEW_VM}'..."
limactl clone --yes "$OLD_VM" "$NEW_VM"

if [ "$STATUS" = "Running" ]; then
    echo "Restarting '${OLD_VM}'..."
    limactl start "$OLD_VM"
fi
