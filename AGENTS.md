# AGENTS.md

This is the `agt_agent_sandbox` fork of [toybox](https://github.com/landley/toybox).

## IMPORTANT: No Deletions

Never delete files. If something needs to be cleaned up, move it to `.tmp/` which is gitignored:

```bash
mv unwanted_file.sh .tmp/
```

This preserves work that may not yet be committed.

## Purpose

Exploring VM setup with chroot jails that use toybox as an all-in-one environment for agent sandboxing.

## Upstream Sync

This fork can take updates from upstream toybox:

```bash
git fetch upstream
git merge upstream/master
```

## Project Structure

All sandbox-related code lives in `agt_agent_sandbox/` to avoid conflicts with upstream:

```
agt_agent_sandbox/
├── Justfile                    # Command runner recipes
├── mise.toml                   # Tool version management
├── agt_agent_sandbox.yaml      # Lima VM configuration
└── agt_agent_sandbox_lima.sh   # VM setup script
```

## Setup

We use [mise](https://mise.jdx.dev/) for tool versions and [just](https://just.systems/) as a command runner.

### One-time shell setup (zsh)

Install direnv and mise, then configure them to auto-activate per-project:

```bash
brew install mise direnv

# Add direnv hook to zsh
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# Configure direnv to use mise
mkdir -p ~/.config/direnv
echo 'use_mise() { direnv_load mise direnv exec; }' > ~/.config/direnv/direnvrc

source ~/.zshrc
```

### Project setup

```bash
cd /path/to/toybox
cp .envrc.example .envrc # Create local env config (gitignored)
direnv allow    # Approve the .envrc file
mise trust      # Trust mise.toml
mise install    # Install tools (just)
```

After this, `just` will be available whenever you're in this directory.

## Build Artifacts

Build outputs (binaries) should be placed in `dist/`, which is ignored by git.

## Commands

Run from the repo root:

```bash
just                # List all commands
just lint           # Run yamllint + shellcheck
just lima-up        # Create and start the Lima VM
just lima-shell     # Open a shell in the VM
just lima-stop      # Stop the VM
just lima-delete    # Delete the VM
```
