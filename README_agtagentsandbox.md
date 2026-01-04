# AGT Agent Sandbox

This project uses `toybox` to explore VM-based agent sandboxing with chroot jails. It is designed to be self-contained within the `agt_agent_sandbox/` directory to avoid conflicts with upstream `toybox` development.

## Setup

We use [mise](https://mise.jdx.dev/) for tool management and [just](https://just.systems/) as a command runner.

### Automatic Setup (Recommended)
If you have `direnv` and `mise` installed, simply:
1. `direnv allow`
2. `mise trust`
3. `mise install`

### Manual Setup
If you don't use `direnv`, you can still use the tools via `mise`:
1. Install [mise](https://mise.jdx.dev/)
2. Run commands using `mise exec`:
   ```bash
   mise exec -- just lima-up
   ```
   Or add `~/.local/share/mise/installs/just/latest/bin` to your PATH after running `mise install`.

## Commands

All lifecycle commands are managed via `just`:

- `just lima-up`: Create and start the Lima VM.
- `just lima-shell`: Open a shell in the VM.
- `just lima-clone <new_name>`: Clone the current sandbox VM to a new instance.
- `just lima-stop`: Stop the VM.
- `just lima-delete`: Delete the VM.

## Snapshots & Rollback

Since this project uses the `vz` driver on macOS, traditional `limactl snapshot` commands are currently unimplemented. To preserve a clean state:
1. Use `just lima-clone clean-backup` to create a "gold image".
2. Or use `limactl factory-reset agt_agent_sandbox` to return to the initial provisioned state.
