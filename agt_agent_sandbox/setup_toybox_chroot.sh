#!/bin/sh
# shellcheck disable=SC2016

# Toybox Chroot Jail Setup Script for macOS
# This script creates a chroot jail with toybox and runs opencode web inside it

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

# Configuration
CHROOT_DIR="/tmp/toybox_chroot"
TOYBOX_BIN="/Users/Shared/toybox/toybox"
HIGH_PORT=9999

# Find an available high port
find_high_port() {
    port=$1
    while true; do
        if ! lsof -i :"$port" >/dev/null 2>&1; then
            echo "$port"
            return
        fi
        port=$((port + 1))
        if [ "$port" -gt 65535 ]; then
            echo "No available high ports found"
            exit 1
        fi
    done
}

HIGH_PORT=$(find_high_port $HIGH_PORT)

echo "Using port: $HIGH_PORT"

# Clean up any existing chroot
if [ -d "$CHROOT_DIR" ]; then
    echo "Cleaning up existing chroot..."
    umount "$CHROOT_DIR/proc" 2>/dev/null || true
    umount "$CHROOT_DIR/dev" 2>/dev/null || true
    rm -rf "$CHROOT_DIR"
fi

echo "Creating chroot directory structure..."
mkdir -p "$CHROOT_DIR"
mkdir -p "$CHROOT_DIR/bin"
mkdir -p "$CHROOT_DIR/lib"
mkdir -p "$CHROOT_DIR/usr/bin"
mkdir -p "$CHROOT_DIR/usr/lib"
mkdir -p "$CHROOT_DIR/etc"
mkdir -p "$CHROOT_DIR/dev"
mkdir -p "$CHROOT_DIR/proc"
mkdir -p "$CHROOT_DIR/tmp"
mkdir -p "$CHROOT_DIR/home"

echo "Setting up basic system files..."
# Create minimal /etc files
cat > "$CHROOT_DIR/etc/passwd" << EOFP
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
EOFP

cat > "$CHROOT_DIR/etc/group" << EOFG
root:x:0:
nobody:x:65534:
EOFG

cat > "$CHROOT_DIR/etc/hosts" << EOFH
127.0.0.1	localhost
::1		localhost ip6-localhost ip6-loopback
EOFH

echo "Copying toybox and creating symlinks..."
# Copy toybox binary
cp "$TOYBOX_BIN" "$CHROOT_DIR/bin/"

# Create symlinks for all toybox commands
cd "$CHROOT_DIR/bin"
for cmd in $(./toybox); do
    ln -sf toybox "$cmd"
done

# Also create some common locations
cd "$CHROOT_DIR/usr/bin"
for cmd in $(./../bin/toybox); do
    ln -sf ../bin/toybox "$cmd"
done

echo "Setting up device nodes..."
# Create basic device nodes
mknod -m 666 "$CHROOT_DIR/dev/null" c 1 3
mknod -m 666 "$CHROOT_DIR/dev/zero" c 1 5
mknod -m 666 "$CHROOT_DIR/dev/random" c 1 8
mknod -m 666 "$CHROOT_DIR/dev/urandom" c 1 9
mknod -m 644 "$CHROOT_DIR/dev/console" c 5 1
mknod -m 666 "$CHROOT_DIR/dev/tty" c 5 0
mknod -m 666 "$CHROOT_DIR/dev/tty0" c 4 0

echo "Setting up proc filesystem..."
# Mount proc filesystem
mount -t proc proc "$CHROOT_DIR/proc"

echo "Setting up devpts..."
# Create devpts for terminal access
mkdir -p "$CHROOT_DIR/dev/pts"
mount -t devpts devpts "$CHROOT_DIR/dev/pts"

echo "Setting permissions..."
chmod 755 "$CHROOT_DIR"
chmod 755 "$CHROOT_DIR/bin"
chmod 755 "$CHROOT_DIR/usr/bin"
chmod 755 "$CHROOT_DIR/etc"
chmod 755 "$CHROOT_DIR/dev"
chmod 755 "$CHROOT_DIR/proc"
chmod 755 "$CHROOT_DIR/tmp"
chmod 755 "$CHROOT_DIR/home"

echo "Chroot jail setup complete!"
echo "Chroot directory: $CHROOT_DIR"
echo "Port: $HIGH_PORT"

echo "Starting opencode web in chroot jail..."

# Start opencode web in the chroot
chroot "$CHROOT_DIR" /bin/sh -c '
    export PATH=/bin:/usr/bin
    export HOME=/home
    export USER=root
    export SHELL=/bin/sh
    
    # Create a simple test file to verify chroot
    echo "Chroot test file" > /tmp/chroot_test.txt
    
    # Start opencode web on the high port
    echo "Starting opencode web on port '"$HIGH_PORT"'..."
    
    # Check if opencode is available
    if command -v opencode >/dev/null 2>&1; then
        opencode web --port '"$HIGH_PORT"'
    else
        echo "opencode not found in chroot. Installing basic web server..."
        # Fallback: create a simple HTTP server using toybox
        while true; do
            printf "HTTP/1.1 200 OK\r\n\r\n"
            printf "<html><body><h1>Toybox Chroot Jail</h1>"
            printf "<p>This is running inside a chroot jail with toybox.</p>"
            printf "<p>Port: '"$HIGH_PORT"'</p>"
            printf "<p>Chroot test: %s</p>" "$(cat /tmp/chroot_test.txt 2>/dev/null || echo failed)"
            printf "</body></html>"
        done | nc -l -p '"$HIGH_PORT"'
    fi
'

echo ""
echo "=========================================="
echo "Toybox Chroot Jail Information:"
echo "=========================================="
echo "Chroot directory: $CHROOT_DIR"
echo "Web server port: $HIGH_PORT"
echo "Access URL: http://localhost:$HIGH_PORT"
echo ""
echo "To test the chroot jail:"
echo "1. Access the web server at http://localhost:$HIGH_PORT"
echo "2. You should see a page confirming it's running in the chroot"
echo "3. The chroot_test.txt file should be readable"
echo ""
echo "To clean up later, run:"
echo "  umount $CHROOT_DIR/proc"
echo "  umount $CHROOT_DIR/dev/pts"
echo "  rm -rf $CHROOT_DIR"
echo "=========================================="
