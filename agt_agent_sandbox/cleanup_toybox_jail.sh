#!/bin/sh

# Cleanup script for toybox jail

JAIL_DIR="/tmp/toybox_jail"
CHROOT_DIR="/tmp/toybox_chroot"

echo "Cleaning up toybox environments..."

# Kill any running web servers
pkill -f "web_server.sh" 2>/dev/null || true
pkill -f "nc -l -p" 2>/dev/null || true

# Clean up chroot
if [ -d "$CHROOT_DIR" ]; then
    echo "Cleaning up chroot..."
    umount "$CHROOT_DIR/proc" 2>/dev/null || true
    umount "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount "$CHROOT_DIR/dev" 2>/dev/null || true
    rm -rf "$CHROOT_DIR"
fi

# Clean up jail
if [ -d "$JAIL_DIR" ]; then
    echo "Cleaning up jail..."
    rm -rf "$JAIL_DIR"
fi

echo "Cleanup complete!"
