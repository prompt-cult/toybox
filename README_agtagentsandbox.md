# AGT Agent Sandbox

This is a fork of `toybox` that serves as the foundation for jailing LLM agents (starting with opencode, later others) in isolated chroot environments on a Lima VM. The primary purpose is to provide secure execution contexts for AI agents while maintaining security updates from upstream `toybox`.

## Purpose

- **Jail LLM Agents**: Run code-generation and tool-use agents (like opencode) safely in isolated chroot jails
- **Filesystem Isolation**: Agents cannot access the host filesystem or affect other agents' environments
- **Concurrent Execution**: Multiple agents can run simultaneously in separate jails
- **Security**: Track and apply upstream `toybox` security updates while adding agent-specific tooling

The project is designed to be self-contained within the `agt_agent_sandbox/` directory to avoid conflicts with upstream `toybox` development.

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

## Testing & Verification

The system includes automated and manual testing procedures to verify agent jailing works correctly:

- **Automated**: Run `just lima-verify-run` for a complete verification (deploys jails + runs concurrency test)
- **Manual**: See `tests/exploratory/manual_jail_test.md` for step-by-step procedures to:
  - Verify binaries are installed in the Lima VM
  - Test chroot jail isolation
  - Confirm concurrent execution of multiple agents
  - Check filesystem isolation between jails

## HTTPS Support in wget

`toybox wget` supports HTTPS URLs when built with `TOYBOX_LIBCRYPTO=y` (OpenSSL). The build
script (`agt_agent_sandbox/lima_build.sh`) automatically installs `libssl-dev` and enables this
option, so HTTPS is available in the Lima VM by default.

**TLS validation behaviour:** Certificates are validated against the system trust store
(`SSL_CTX_set_default_verify_paths`). Connections to hosts with invalid or untrusted certificates
will be rejected. Ensure the system CA bundle (`ca-certificates`) is installed and up-to-date.

**Redirects:** HTTP 301/302 redirects are followed automatically (up to `--max-redirect`, default 20),
which handles GitHub Release URLs that redirect through CDN endpoints.

## Container image (GHCR)

The fork publishes a minimal, from-scratch toybox container image built with a fully static
musl + OpenSSL toybox binary (`CONFIG_TOYBOX_LIBCRYPTO=y`, so `wget https://` works):

- `ghcr.io/prompt-cult/toybox:<YYYY.MM.DD-<short-sha>>` — stable line, built from the `prompt-cult` branch
- `ghcr.io/prompt-cult/toybox:agt-<YYYY.MM.DD-<short-sha>>` — experimental agent-sandbox line, built from the `agt-agent-sandbox` branch

Both are multi-arch (`linux/amd64`, `linux/arm64`) and are published by
`.github/workflows/ghcr.yml` when a matching tag is pushed. The image is
`FROM scratch` with the static binary as `/bin/toybox`, an `/bin/sh` applet
symlink, and the system CA bundle baked in at `/etc/ssl/cert.pem`
(`SSL_CTX_set_default_verify_paths` resolves it), so TLS validation works
without a distro underneath.

Usage:

```sh
docker run --rm ghcr.io/prompt-cult/toybox:<tag> sh -c 'ls / && echo hi'
docker run --rm ghcr.io/prompt-cult/toybox:<tag> wget -O- https://raw.githubusercontent.com/landley/toybox/master/README
```

Local build (works on colima where bind mounts are unreliable — the build context is sent to the daemon):

```sh
docker build -t ghcr.io/prompt-cult/toybox:local .
docker run --rm ghcr.io/prompt-cult/toybox:local wget -O- https://example.com
```
