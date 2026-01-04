#!/bin/sh
set -eu

if ! command -v limactl >/dev/null 2>&1; then
    echo "Error: limactl not found. Install Lima first." >&2
    exit 1
fi

limactl list
