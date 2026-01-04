#!/usr/bin/env python3
"""
oc_manager.py - Parallel Agent Orchestrator for Chroot Jails
"""
import argparse
import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

JAIL_BASE = Path("/tmp/chroots")
TIMEOUT_SECONDS = 30

def setup_jail_worktree(jail_id, prompt_file, run_id):
    """Prepares the worktree inside the jail."""
    jail_dir = JAIL_BASE / jail_id
    worktree = jail_dir / "home/worktree"
    
    # Ensure clean worktree
    if worktree.exists():
        shutil.rmtree(worktree)
    worktree.mkdir(parents=True, exist_ok=True)
    
    # Inject Prompt with Parameters
    prompt_content = prompt_file.read_text()
    
    # Prepend parameters for the agent to read
    params_block = f"""<PROMPT-PARAMETERS>
- JAIL_ID={jail_id}
- RUN_ID={run_id}
- TIMESTAMP={datetime.datetime.now().isoformat()}
</PROMPT-PARAMETERS>

"""
    final_prompt = params_block + prompt_content
    (worktree / "prompt.md").write_text(final_prompt)
    
    # Create the Agent Script (Simulation of opencode)
    # This script mimics an agent that reads prompt.md, does work, and writes a log
    agent_script = r"""
import { file, write } from "bun";
import { existsSync, mkdirSync } from "fs";

console.log(`[Agent] Starting in ${process.cwd()}`);

// Read Prompt
const prompt = await file("prompt.md").text();
const jailIdMatch = prompt.match(/JAIL_ID=(.*)/);
const jailId = jailIdMatch ? jailIdMatch[1] : "UNKNOWN";

console.log(`[Agent] Detected Jail ID: ${jailId}`);

// Simulate Thinking/Working
const steps = 3;
const logDir = "Reports";
if (!existsSync(logDir)) mkdirSync(logDir);

let logContent = `# Agent Log for ${jailId}\nStarted: ${new Date().toISOString()}\n\n`;

for (let i = 1; i <= steps; i++) {
    console.log(`[Agent] Executing Step ${i}...`);
    await new Promise(r => setTimeout(r, 1000)); // Sleep 1s
    logContent += `- Step ${i} completed at ${new Date().toISOString()}\n`;
}

logContent += `\nOutcome: SUCCESS\n`;
await write(`${logDir}/LOG.md`, logContent);
console.log("[Agent] Finished.");
"""
    (worktree / "agent.js").write_text(agent_script)
    
    return worktree

def run_agent_in_jail(jail_id):
    """Executes the agent inside the chroot."""
    jail_dir = JAIL_BASE / jail_id
    
    cmd = [
        "sudo", "chroot", str(jail_dir),
        "/bin/sh", "-c",
        "cd /home/worktree && bun agent.js"
    ]
    
    print(f"[{jail_id}] Launching agent...")
    start = time.time()
    
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT_SECONDS)
        duration = time.time() - start
        
        return {
            "id": jail_id,
            "success": proc.returncode == 0,
            "duration": duration,
            "stdout": proc.stdout,
            "stderr": proc.stderr
        }
    except subprocess.TimeoutExpired:
        return {
            "id": jail_id,
            "success": False,
            "duration": TIMEOUT_SECONDS,
            "error": "Timeout"
        }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("prompt_file", type=Path)
    parser.add_argument("--jails", nargs="+", default=["jail1", "jail2"])
    args = parser.parse_args()
    
    if not args.prompt_file.exists():
        print(f"Error: Prompt file {args.prompt_file} not found")
        sys.exit(1)

    print(f"--- Starting Orchestration for {len(args.jails)} Jails ---")
    
    # 1. Setup Phase
    import datetime # Import locally to avoid scope issues in helper
    run_id = f"RUN-{int(time.time())}"
    
    for jail in args.jails:
        setup_jail_worktree(jail, args.prompt_file, run_id)
        
    # 2. Execution Phase (Parallel)
    results = []
    with concurrent.futures.ThreadPoolExecutor() as executor:
        future_to_jail = {executor.submit(run_agent_in_jail, jail): jail for jail in args.jails}
        
        for future in concurrent.futures.as_completed(future_to_jail):
            jail = future_to_jail[future]
            try:
                data = future.result()
                results.append(data)
                status = "SUCCESS" if data["success"] else "FAILED"
                print(f"[{jail}] Finished: {status} ({data['duration']:.2f}s)")
            except Exception as exc:
                print(f"[{jail}] Exception: {exc}")
                
    # 3. Report Phase
    print("\n--- Final Report ---")
    success_count = sum(1 for r in results if r["success"])
    print(f"Total: {len(results)}, Success: {success_count}, Failed: {len(results) - success_count}")
    
    for r in results:
        if not r["success"]:
            print(f"\n[{r['id']}] FAILURE OUTPUT:")
            print(f"STDOUT:\n{r.get('stdout', '')}")
            print(f"STDERR:\n{r.get('stderr', '')}")
            print(f"ERROR: {r.get('error', '')}")
            
    # Verify Isolation (Check that logs are unique)
    print("\n--- Verifying Content ---")
    for jail in args.jails:
        log_path = JAIL_BASE / jail / "home/worktree/Reports/LOG.md"
        if log_path.exists():
            content = log_path.read_text()
            if f"Agent Log for {jail}" in content:
                 print(f"[{jail}] Verified: Log contains correct Jail ID")
            else:
                 print(f"[{jail}] ERROR: Log content mismatch!")
        else:
            print(f"[{jail}] ERROR: Log file not found!")

if __name__ == "__main__":
    import datetime
    main()
