# Justfile for agt_agent_sandbox fork

# Default recipe
default:
    @just --list

# Lint YAML files
lint-yaml:
    yamllint agt_agent_sandbox/agt_agent_sandbox.yaml

# Lint shell scripts
lint-shell:
    shellcheck -s sh agt_agent_sandbox/*.sh

# Run all lints
lint: lint-yaml lint-shell

# Create and start the Lima VM
lima-up:
    ./agt_agent_sandbox/agt_agent_sandbox_lima.sh

# Stop the Lima VM
lima-stop:
    ./agt_agent_sandbox/lima_stop.sh

# Delete the Lima VM
lima-delete:
    ./agt_agent_sandbox/lima_delete.sh

# Show Lima VM status
lima-status:
    ./agt_agent_sandbox/lima_status.sh

# List all Lima VMs
lima-list:
    limactl list

# Open a shell in the Lima VM
lima-shell:
    ./agt_agent_sandbox/lima_shell.sh

# Build and install toybox inside the Lima VM
lima-install:
    limactl shell agt_agent_sandbox < ./agt_agent_sandbox/lima_build.sh

# Factory reset and reinstall toybox
lima-reset:
    limactl factory-reset agt_agent_sandbox
    just lima-install

# Clone the Lima VM
lima-clone new_name:
    ./agt_agent_sandbox/lima_clone.sh {{new_name}}

# Restore the Lima VM from a backup
lima-restore backup_name:
    ./agt_agent_sandbox/lima_restore.sh {{backup_name}}

# Deploy and setup Chroot Jails with Bun (manual args)
# Usage: just lima-deploy-jails jail1 jail2 ...
lima-deploy-jails +args:
    chmod +x agt_agent_sandbox/setup_bun_chroot.sh
    limactl shell agt_agent_sandbox < ./agt_agent_sandbox/setup_bun_chroot.sh -- {{args}}

# Run a full verification pass with timestamped jails
lima-verify-run:
    ./agt_agent_sandbox/run_verification_host.sh

# Verify Jail Functionality (Manual Step)
lima-verify-jail jail_id="jail1":
    @echo "Checking bun version in {{jail_id}}..."
    limactl shell agt_agent_sandbox sudo chroot /tmp/chroots/{{jail_id}} /bin/bun --version
    @echo "Checking toybox version in {{jail_id}}..."
    limactl shell agt_agent_sandbox sudo chroot /tmp/chroots/{{jail_id}} /bin/toybox --version
