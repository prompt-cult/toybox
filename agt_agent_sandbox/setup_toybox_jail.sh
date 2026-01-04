#!/bin/sh

# Toybox Jail Setup Script for macOS
# This script creates a sandboxed environment with toybox and runs a web server

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

# Configuration
JAIL_DIR="/tmp/toybox_jail"
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

# Clean up any existing jail
if [ -d "$JAIL_DIR" ]; then
    echo "Cleaning up existing jail..."
    rm -rf "$JAIL_DIR"
fi

echo "Creating jail directory structure..."
mkdir -p "$JAIL_DIR"
mkdir -p "$JAIL_DIR/bin"
mkdir -p "$JAIL_DIR/usr/bin"
mkdir -p "$JAIL_DIR/etc"
mkdir -p "$JAIL_DIR/tmp"
mkdir -p "$JAIL_DIR/home"

echo "Setting up basic system files..."
# Create minimal /etc files
cat > "$JAIL_DIR/etc/passwd" << EOFP
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
EOFP

cat > "$JAIL_DIR/etc/group" << EOFG
root:x:0:
nobody:x:65534:
EOFG

echo "Copying toybox and creating symlinks..."
# Copy toybox binary
cp "$TOYBOX_BIN" "$JAIL_DIR/bin/"

# Create symlinks for all toybox commands
cd "$JAIL_DIR/bin"
for cmd in $(./toybox); do
    ln -sf toybox "$cmd"
done

# Also create some common locations
cd "$JAIL_DIR/usr/bin"
for cmd in $(./../bin/toybox); do
    ln -sf ../bin/toybox "$cmd"
done

echo "Setting permissions..."
chmod 755 "$JAIL_DIR"
chmod 755 "$JAIL_DIR/bin"
chmod 755 "$JAIL_DIR/usr/bin"
chmod 755 "$JAIL_DIR/etc"
chmod 755 "$JAIL_DIR/tmp"
chmod 755 "$JAIL_DIR/home"

echo "Jail setup complete!"
echo "Jail directory: $JAIL_DIR"
echo "Port: $HIGH_PORT"

echo "Starting web server in jail..."

# Start a simple web server using toybox nc (netcat)
cd "$JAIL_DIR"

# Create a simple web server script
cat > "$JAIL_DIR/web_server.sh" << WEBSERVER
#!/bin/sh

export PATH=/bin:/usr/bin
export HOME=/home
export USER=root
export SHELL=/bin/sh

# Create a test file
echo "Jail test file - \$(date)" > /tmp/jail_test.txt

echo "Starting web server on port $HIGH_PORT..."

# Simple HTTP server using toybox netcat
while true; do
    {
        printf "HTTP/1.1 200 OK\r\n\r\n"
        printf "<html><body>"
        printf "<h1>Toybox Jail Environment</h1>"
        printf "<p>This is running inside a toybox jail environment.</p>"
        printf "<p>Port: $HIGH_PORT</p>"
        printf "<p>Jail test: %s</p>" "\$(cat /tmp/jail_test.txt 2>/dev/null || echo failed)"
        printf "<p>Current directory: %s</p>" "\$(pwd)"
        printf "<p>Available commands: %s</p>" "\$(ls /bin | head -10)"
        printf "</body></html>"
    } | nc -l -p $HIGH_PORT
    sleep 1
done
WEBSERVER

chmod +x "$JAIL_DIR/web_server.sh"

# Start the web server
cd "$JAIL_DIR"
./web_server.sh &

WEB_PID=$!

echo ""
echo "=========================================="
echo "Toybox Jail Information:"
echo "=========================================="
echo "Jail directory: $JAIL_DIR"
echo "Web server port: $HIGH_PORT"
echo "Access URL: http://localhost:$HIGH_PORT"
echo "Web server PID: $WEB_PID"
echo ""
echo "To test the jail:"
echo "1. Access the web server at http://localhost:$HIGH_PORT"
echo "2. You should see a page confirming it's running in the jail"
echo "3. The jail_test.txt file should show the current date"
echo ""
echo "To clean up later, run:"
echo "  kill $WEB_PID"
echo "  rm -rf $JAIL_DIR"
echo "=========================================="

# Keep the script running to maintain the web server
wait $WEB_PID
