#!/bin/bash
set -e

# 1. Create the Worker Script (to run inside jail)
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

# 2. Deploy Worker to Jails
echo "Deploying workers..."
sudo cp /tmp/worker.js /tmp/chroots/jail1/bin/worker.js
sudo cp /tmp/worker.js /tmp/chroots/jail2/bin/worker.js

# 3. Launch in Parallel
echo "Launching Jails in parallel..."
# We use & to background them
sudo chroot /tmp/chroots/jail1 /bin/bun /bin/worker.js jail1 2000 &
PID1=$!
sudo chroot /tmp/chroots/jail2 /bin/bun /bin/worker.js jail2 2000 &
PID2=$!

echo "Jail1 PID: $PID1"
echo "Jail2 PID: $PID2"

# 4. Wait for completion
wait $PID1
wait $PID2
echo "Both jails finished."

# 5. Verification
echo "--- Verification ---"

# Check output files
if [ -f "/tmp/chroots/jail1/tmp/jail1.out" ]; then
    echo "✅ Jail1 output found"
else
    echo "❌ Jail1 output MISSING"
    exit 1
fi

if [ -f "/tmp/chroots/jail2/tmp/jail2.out" ]; then
    echo "✅ Jail2 output found"
else
    echo "❌ Jail2 output MISSING"
    exit 1
fi

# Check Isolation (Jail1 file should NOT be in Jail2)
if [ -f "/tmp/chroots/jail2/tmp/jail1.out" ]; then
     echo "❌ FAIL: Isolation broken (jail1.out found in jail2)"
     exit 1
else
     echo "✅ Isolation verified"
fi

# Check Concurrency (Time Overlap)
# Read logs
J1_START=$(cat /tmp/chroots/jail1/tmp/jail1.start)
J1_END=$(cat /tmp/chroots/jail1/tmp/jail1.end)
J2_START=$(cat /tmp/chroots/jail2/tmp/jail2.start)
J2_END=$(cat /tmp/chroots/jail2/tmp/jail2.end)

echo "Jail1: $J1_START -> $J1_END"
echo "Jail2: $J2_START -> $J2_END"

# Logic: Jail2 Start must be BEFORE Jail1 End (and vice versa)
if [ "$J2_START" -lt "$J1_END" ] && [ "$J1_START" -lt "$J2_END" ]; then
    echo "✅ Concurrency verified (Timestamps overlap)"
else
    echo "❌ FAIL: No overlap detected (Sequential execution?)"
    exit 1
fi

exit 0
