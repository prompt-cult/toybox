#!/usr/bin/env python3
"""
oc_isolation.py - Agent Isolation Manager (Runs on Host, manages Jails)
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# --- Constants ---
JAIL_BASE = Path("/tmp/chroots")

def get_timestamp():
    return datetime.datetime.now().isoformat(timespec='seconds')

def cmd_run(args):
    jail_id = args.jail_id
    prompt_file = Path(args.prompt_file).resolve()
    
    jail_dir = JAIL_BASE / jail_id
    if not jail_dir.exists():
        print(f"Error: Jail {jail_id} not found at {jail_dir}")
        sys.exit(1)
        
    print(f"Running agent in jail: {jail_id}")
    
    # 1. Prepare Inputs in Jail
    # We map the jail's /worktree to a specific path inside the jail directory
    worktree_in_jail = jail_dir / "home/worktree"
    worktree_in_jail.mkdir(parents=True, exist_ok=True)
    
    # Copy prompt file
    shutil.copy(prompt_file, worktree_in_jail / "prompt.md")
    
    # Create the script to run INSIDE the chroot
    # We will run a simple bun script that mimics opencode for this test
    # ensuring it can write files and read the prompt
    
    agent_script_content = r"""
import { file, write } from "bun";

console.log("Starting Mock Agent in Jail");
console.log("CWD:", process.cwd());

// Read prompt
const prompt = await file("prompt.md").text();
console.log("Prompt read successfully");

// Parse params from prompt (simple check)
const lines = prompt.split("\n");
const params = {};
let inParams = false;
for (const line of lines) {
    if (line.includes("<PROMPT-PARAMETERS>")) { inParams = true; continue; }
    if (line.includes("</PROMPT-PARAMETERS>")) { inParams = false; continue; }
    if (inParams && line.trim()) {
        const [k, v] = line.trim().replace(/^- /, "").split("=");
        if (k && v) params[k] = v;
    }
}

console.log("Parameters:", params);

// Simulate "Work" - write log file
const logDir = "Reports";
const fs = require("fs");
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir);

const logFile = `${logDir}/LOG.md`;
let logContent = `# Agent Log
**Started**: ${new Date().toISOString()}
## Parameters
${JSON.stringify(params, null, 2)}
## Messages
`;

// Simulate steps
for (let i = 1; i <= 3; i++) {
    console.log(`Step ${i}...`);
    await new Promise(r => setTimeout(r, 1000)); // Sleep 1s
    logContent += `- [${new Date().toISOString().split("T")[1].split(".")[0]}] Hello World ${i}\n`;
}

logContent += `## Outcome
SUCCESS
**Completed**: ${new Date().toISOString()}
`;

await write(logFile, logContent);
console.log("Finished writing log");
"""
    
    with open(worktree_in_jail / "agent.js", "w") as f:
        f.write(agent_script_content)
        
    # 2. Execute in Chroot
    # We use sudo chroot ... bun agent.js
    
    cmd = [
        "sudo", "chroot", str(jail_dir),
        "/bin/sh", "-c",
        "cd /home/worktree && bun agent.js"
    ]
    
    print(f"Exec: {' '.join(cmd)}")
    
    proc = subprocess.run(cmd)
    
    if proc.returncode == 0:
        print(f"Agent {jail_id} Success")
        # Cat the log file from the jail to verify
        log_path = worktree_in_jail / "Reports/LOG.md"
        if log_path.exists():
            print("\n--- Generated Log ---")
            print(log_path.read_text())
            print("---------------------")
    else:
        print(f"Agent {jail_id} Failed")
        sys.exit(proc.returncode)

def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    p_run = subparsers.add_parser("run")
    p_run.add_argument("jail_id")
    p_run.add_argument("prompt_file")
    p_run.set_defaults(func=cmd_run)
    
    args = parser.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
