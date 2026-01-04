#!/bin/sh
# Shellcheck compliant and POSIX-friendly build script for toybox inside Lima

set -eu

REPO_URL="https://github.com/simbo1905/toybox.git"
BRANCH="agt-agent-sandbox"
BUILD_DIR="${HOME}/toybox-build"
INSTALL_PREFIX="/usr/local/bin"

check_deps() {
    echo "Checking dependencies..."
    # Only update if necessary (using a 1-day cache check would be better, but -qq is quiet)
    sudo apt-get update -qq
    sudo apt-get install -qq -y build-essential git ca-certificates
}

setup_repo() {
    if [ ! -d "$BUILD_DIR" ]; then
        echo "Cloning repository..."
        git clone --branch "$BRANCH" "$REPO_URL" "$BUILD_DIR"
    else
        echo "Checking repository state..."
        cd "$BUILD_DIR"
        # Only pull if the working directory is clean
        if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "Notice: Local changes detected in $BUILD_DIR. Skipping git pull to preserve work."
        else
            echo "Updating repository..."
            git fetch origin -q
            git checkout "$BRANCH" -q
            git pull origin "$BRANCH" -q
        fi
    fi
}

build_toybox() {
    cd "$BUILD_DIR"
    
    # Determine version
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
    COMMIT_HASH=$(git rev-parse --short HEAD)
    VERSION="${LATEST_TAG}-${COMMIT_HASH}"
    
    # Check if this version is already built and installed
    if [ -x "${INSTALL_PREFIX}/toybox-${VERSION}" ] && [ -x "toybox" ]; then
        # Check if the symlink is also correct
        if [ "$(readlink -f "${INSTALL_PREFIX}/toybox")" = "${INSTALL_PREFIX}/toybox-${VERSION}" ]; then
            echo "Toybox ${VERSION} is already built and correctly installed."
            return 0
        fi
    fi

    echo "Building toybox version: $VERSION"
    
    # Only configure if no .config exists
    if [ ! -f ".config" ]; then
        echo "Initializing default config..."
        make defconfig
    fi
    
    # Perform incremental build (no make clean)
    make -j"$(nproc)"
    
    if [ ! -f "toybox" ]; then
        echo "Error: Build failed, toybox binary not found." >&2
        exit 1
    fi
}

install_toybox() {
    cd "$BUILD_DIR"
    # Re-calculate version
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
    COMMIT_HASH=$(git rev-parse --short HEAD)
    VERSION="${LATEST_TAG}-${COMMIT_HASH}"

    if [ "$(readlink -f "${INSTALL_PREFIX}/toybox")" = "${INSTALL_PREFIX}/toybox-${VERSION}" ] && [ -x "${INSTALL_PREFIX}/toybox-${VERSION}" ]; then
        return 0
    fi

    echo "Installing to $INSTALL_PREFIX..."
    sudo cp toybox "${INSTALL_PREFIX}/toybox-${VERSION}"
    sudo ln -sf "${INSTALL_PREFIX}/toybox-${VERSION}" "${INSTALL_PREFIX}/toybox"
    
    echo "Successfully installed: ${INSTALL_PREFIX}/toybox-${VERSION}"
}

run_all() {
    check_deps
    setup_repo
    build_toybox
    install_toybox
}

# Entry point
if [ "${1:-}" = "all" ] || [ -z "${1:-}" ]; then
    run_all
else
    "$@"
fi
