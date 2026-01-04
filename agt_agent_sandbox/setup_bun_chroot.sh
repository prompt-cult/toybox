#!/bin/sh
set -e

# Configuration
CHROOT_BASE="${CHROOT_BASE:-/tmp/chroots}"
TOYBOX_BIN="/usr/local/bin/toybox"
# Dynamically find bun or fall back to standard user location
if command -v bun >/dev/null 2>&1; then
    BUN_BIN="$(command -v bun)"
elif [ -f "$HOME/.bun/bin/bun" ]; then
    BUN_BIN="$HOME/.bun/bin/bun"
else
    BUN_BIN="/home/consensussolutions.linux/.bun/bin/bun"
fi

# Check dependencies
if [ ! -f "$TOYBOX_BIN" ]; then
    echo "Error: toybox not found at $TOYBOX_BIN"
    exit 1
fi
if [ ! -f "$BUN_BIN" ]; then
    echo "Error: bun not found at $BUN_BIN"
    exit 1
fi

create_jail() {
    JAIL_ID=$1
    JAIL_DIR="${CHROOT_BASE}/${JAIL_ID}"
    
    echo "Creating jail: $JAIL_DIR"
    
    # Clean up old jail
    if [ -d "$JAIL_DIR" ]; then
        sudo umount "$JAIL_DIR/proc" 2>/dev/null || true
        sudo umount "$JAIL_DIR/dev" 2>/dev/null || true
        sudo rm -rf "$JAIL_DIR"
    fi
    
    mkdir -p "$JAIL_DIR"
    mkdir -p "$JAIL_DIR/bin"
    mkdir -p "$JAIL_DIR/usr/bin"
    mkdir -p "$JAIL_DIR/lib"
    mkdir -p "$JAIL_DIR/lib/aarch64-linux-gnu"
    mkdir -p "$JAIL_DIR/etc"
    mkdir -p "$JAIL_DIR/tmp"
    mkdir -p "$JAIL_DIR/home"
    mkdir -p "$JAIL_DIR/proc"
    mkdir -p "$JAIL_DIR/dev"

    # Setup basic /etc
    echo "root:x:0:0:root:/root:/bin/sh" > "$JAIL_DIR/etc/passwd"
    echo "root:x:0:" > "$JAIL_DIR/etc/group"
    echo "nameserver 8.8.8.8" > "$JAIL_DIR/etc/resolv.conf"

    # Copy toybox
    cp "$TOYBOX_BIN" "$JAIL_DIR/bin/toybox"
    
    # Install toybox symlinks (excluding bun/node names if they conflict)
    cd "$JAIL_DIR/bin"
    for cmd in $(./toybox); do
        ln -sf toybox "$cmd"
    done
    cd - >/dev/null

    # Copy Bun
    cp "$BUN_BIN" "$JAIL_DIR/bin/bun"
    ln -sf bun "$JAIL_DIR/bin/node"
    ln -sf bun "$JAIL_DIR/bin/npm"
    ln -sf bun "$JAIL_DIR/bin/npx"

    # Copy Libraries
    echo "Copying libraries..."
    # Get list of libs from ldd, filtering for actual paths (starting with /)
    # Combine libs from bun and toybox
    LIBS=$( (ldd "$BUN_BIN"; ldd "$TOYBOX_BIN") | awk '{print $3}' | grep '^/' | sort -u )
    LD_SO=$(ldd "$BUN_BIN" | grep 'ld-linux' | awk '{print $1}')
    
    # Copy dynamic linker
    if [ -n "$LD_SO" ]; then
        # Ensure directory exists for ld.so (e.g., /lib/ld-linux-aarch64.so.1)
        # Usually it is /lib/... but ldd output might just be filename or full path
        # Check if it starts with /
        case "$LD_SO" in
            /*) 
                mkdir -p "$JAIL_DIR/$(dirname "$LD_SO")"
                cp "$LD_SO" "$JAIL_DIR$LD_SO"
                ;;
            *)
                # If just filename, usually in /lib or /lib64
                # On this ubuntu aarch64, it's likely /lib/ld-linux-aarch64.so.1
                REAL_LD=$(find /lib /usr/lib -name "$LD_SO" | head -1)
                if [ -n "$REAL_LD" ]; then
                   mkdir -p "$JAIL_DIR/$(dirname "$REAL_LD")"
                   cp "$REAL_LD" "$JAIL_DIR$REAL_LD"
                fi
                ;;
        esac
    fi

    # Copy other libs
    for lib in $LIBS; do
        if [ -f "$lib" ]; then
            mkdir -p "$JAIL_DIR/$(dirname "$lib")"
            cp "$lib" "$JAIL_DIR$lib"
        fi
    done
    
    # Install opencode via bun (simulated by checking if we can run bun)
    # In a real scenario, we'd do: chroot "$JAIL_DIR" bun install -g opencode
    # For now, we ensure the PATH includes /bin so bun works
    
    # Mount /proc and /dev for bun to work
    sudo mount -t proc proc "$JAIL_DIR/proc"
    sudo mount --bind /dev "$JAIL_DIR/dev"

    echo "Jail $JAIL_ID ready at $JAIL_DIR"
}

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <jail_id> [jail_id...]"
    echo "Environment variables:"
    echo "  CHROOT_BASE (default: /tmp/chroots)"
    exit 1
fi

for id in "$@"; do
    create_jail "$id"
done
