#!/bin/bash
set -e

CHROOT_BASE="${CHROOT_BASE:-/tmp/chroots}"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <jail_id_1> <jail_id_2> [jail_id_3 ...]"
    exit 1
fi

JAIL_IDS=("$@")

# 1. Create the Worker Script
cat << 'EOF' > /tmp/worker.js
import { write } from "bun";
const id = process.argv[2];
const delay = parseInt(process.argv[3] || "2000");

// Paths inside chroot
const startFile = `/tmp/${id}.start`;
const endFile = `/tmp/${id}.end`;
const outFile = `/tmp/${id}.out`;

console.log(`[${id}] Starting...`);
const start = Date.now();
await write(startFile, `${start}\n`);

// Sleep to force overlap
await new Promise(r => setTimeout(r, delay));

await write(outFile, `Result from ${id}\n`);
console.log(`[${id}] Wrote output`);

// Sleep again
await new Promise(r => setTimeout(r, delay));

const end = Date.now();
await write(endFile, `${end}\n`);
console.log(`[${id}] Finished`);
EOF

# 2. Deploy & Launch
echo "Deploying and Launching workers in ${#JAIL_IDS[@]} jails..."

PIDS=()
for id in "${JAIL_IDS[@]}"; do
    JAIL_PATH="${CHROOT_BASE}/${id}"
    if [ ! -d "$JAIL_PATH" ]; then
        echo "Error: Jail directory $JAIL_PATH not found"
        exit 1
    fi
    
    # Copy worker
    sudo cp /tmp/worker.js "${JAIL_PATH}/bin/worker.js"
    
    # Launch in background
    sudo chroot "$JAIL_PATH" /bin/bun /bin/worker.js "$id" 2000 &
    PID=$!
    PIDS+=("$PID")
    echo "Launched $id (PID: $PID)"
done

# 3. Wait
echo "Waiting for completion..."
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

# 4. Verification
echo "--- Verification ---"
FAIL=0

MIN_START=9999999999999
MAX_START=0
MIN_END=9999999999999
MAX_END=0

for id in "${JAIL_IDS[@]}"; do
    JAIL_PATH="${CHROOT_BASE}/${id}"
    
    # Check output
    if [ -f "${JAIL_PATH}/tmp/${id}.out" ]; then
        echo "✅ [$id] Output found"
    else
        echo "❌ [$id] Output MISSING"
        FAIL=1
    fi
    
    # Check Isolation (verify this ID's file is NOT in other jails)
    for other_id in "${JAIL_IDS[@]}"; do
        if [ "$id" != "$other_id" ]; then
             OTHER_PATH="${CHROOT_BASE}/${other_id}"
             if [ -f "${OTHER_PATH}/tmp/${id}.out" ]; then
                 echo "❌ [$other_id] FAIL: Isolation broken (found ${id}.out)"
                 FAIL=1
             fi
        fi
    done
    
    # Read Timestamps
    if [ -f "${JAIL_PATH}/tmp/${id}.start" ]; then
        S=$(cat "${JAIL_PATH}/tmp/${id}.start")
        E=$(cat "${JAIL_PATH}/tmp/${id}.end")
        
        echo "[$id] $S -> $E"
        
        if [ "$S" -lt "$MIN_START" ]; then MIN_START=$S; fi
        if [ "$S" -gt "$MAX_START" ]; then MAX_START=$S; fi
        if [ "$E" -lt "$MIN_END" ]; then MIN_END=$E; fi
        if [ "$E" -gt "$MAX_END" ]; then MAX_END=$E; fi
    else
        echo "❌ [$id] Timestamps missing"
        FAIL=1
    fi
done

if [ "$FAIL" -eq 1 ]; then
    echo "❌ Verification FAILED"
    exit 1
fi

echo "--- Concurrency Check ---"
echo "Start Range: $MIN_START - $MAX_START"
echo "End Range:   $MIN_END - $MAX_END"

# Strict Overlap: All tasks must have started before ANY task ended.
# (MAX_START < MIN_END)
if [ "$MAX_START" -lt "$MIN_END" ]; then
    echo "✅ Concurrency Verified (All tasks started before any ended)"
else
    echo "❌ Concurrency Check Failed (Some tasks finished before others started)"
    exit 1
fi

exit 0
