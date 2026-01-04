#!/bin/sh
set -eu

TARGET_VM="agt_agent_sandbox"
BACKUP_VM="${1:-}"

if [ -z "$BACKUP_VM" ]; then
    echo "Usage: $0 <backup_vm_name>" >&2
    echo "Check available backups with: just lima-list" >&2
    exit 1
fi

if ! command -v limactl >/dev/null 2>&1; then
    echo "Error: limactl not found." >&2
    exit 1
fi

if ! limactl list --format '{{.Name}}' | grep -qx "$BACKUP_VM"; then
    echo "Error: Backup VM '${BACKUP_VM}' does not exist." >&2
    exit 1
fi

echo "Restoring '${TARGET_VM}' from '${BACKUP_VM}'..."

# Stop and delete the current broken VM if it exists
if limactl list --format '{{.Name}}' | grep -qx "$TARGET_VM"; then
    echo "Stopping current '${TARGET_VM}'..."
    limactl stop "$TARGET_VM" || true
    echo "Deleting current '${TARGET_VM}'..."
    limactl delete "$TARGET_VM"
fi

echo "Cloning backup '${BACKUP_VM}' to '${TARGET_VM}'..."
limactl clone --yes "$BACKUP_VM" "$TARGET_VM"

echo "Starting restored VM..."
limactl start "$TARGET_VM"
