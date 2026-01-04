#!/bin/sh
set -eu

VM_NAME="agt_agent_sandbox"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
YAML_FILE="${SCRIPT_DIR}/agt_agent_sandbox.yaml"

if ! command -v limactl >/dev/null 2>&1; then
    echo "Error: limactl not found. Install Lima first." >&2
    exit 1
fi

if [ ! -f "$YAML_FILE" ]; then
    echo "Error: ${YAML_FILE} not found." >&2
    exit 1
fi

if limactl list --format '{{.Name}}' | grep -qx "$VM_NAME"; then
    echo "VM '${VM_NAME}' already exists."
    STATUS=$(limactl list --format '{{.Name}} {{.Status}}' | grep "^${VM_NAME} " | awk '{print $2}')
    if [ "$STATUS" != "Running" ]; then
        echo "Starting ${VM_NAME}..."
        limactl start "$VM_NAME"
    else
        echo "VM '${VM_NAME}' is already running."
    fi
else
    echo "Creating VM '${VM_NAME}'..."
    limactl create --name="$VM_NAME" "$YAML_FILE"
    echo "Starting ${VM_NAME}..."
    limactl start "$VM_NAME"
fi

echo ""
echo "VM '${VM_NAME}' is ready."
echo "Access with: limactl shell ${VM_NAME}"
