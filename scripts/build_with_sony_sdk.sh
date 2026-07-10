#!/usr/bin/env bash
# Build helper for PS3xPAD using the leaked Sony PS3 SDK 475.001
# This script helps set up the SDK and build the plugin
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SDK_DIR="$PROJECT_DIR/sdk"
SDK_TARBALL="$SDK_DIR/PS3_SDK.tar.gz"
SDK_RAR="$SDK_DIR/PS3_4.75_SDK_Offline_Installer.rar"
SDK_IMAGE="$PROJECT_DIR/src/xpad.sprx"

echo "=== PS3xPAD Sony SDK 475.001 Build Helper ==="
echo ""

# Check if SDK is already extracted
if [ -d "$SDK_DIR/cell" ] && [ -f "$SDK_DIR/cell/host/bin/ppu-lv2-gcc" ]; then
    echo "Found existing SDK at $SDK_DIR/cell"
    SDK_EXTRACTED=true
elif [ -d "$SDK_DIR/PS3_4.75_SDK_Offline_Installer" ] && [ -f "$SDK_DIR/PS3_4.75_SDK_Offline_Installer/cell/host/bin/ppu-lv2-gcc" ]; then
    echo "Found SDK in installer directory at $SDK_DIR/PS3_4.75_SDK_Offline_Installer"
    SDK_EXTRACTED=true
elif [ -f "$SDK_TARBALL" ]; then
    echo "Extracting SDK from $SDK_TARBALL..."
    mkdir -p "$SDK_DIR"
    tar xzf "$SDK_TARBALL" -C "$SDK_DIR"
    SDK_EXTRACTED=true
elif [ -f "$SDK_RAR" ]; then
    echo "Extracting SDK from $SDK_RAR..."
    mkdir -p "$SDK_DIR"
    unrar x -y "$SDK_RAR" "$SDK_DIR/"
    SDK_EXTRACTED=true
else
    echo "ERROR: Sony PS3 SDK 475.001 not found!"
    echo ""
    echo "Please provide the SDK by one of:"
    echo "  1. Place PS3_SDK.tar.gz at: $SDK_TARBALL"
    echo "  2. Extract SDK to: $SDK_DIR/cell/"
    echo "  3. Place RAR installer at: $SDK_RAR"
    exit 1
fi

# Find the cell directory
if [ -d "$SDK_DIR/cell" ]; then
    CELL_DIR="$SDK_DIR/cell"
elif [ -d "$SDK_DIR/PS3_4.75_SDK_Offline_Installer/cell" ]; then
    CELL_DIR="$SDK_DIR/PS3_4.75_SDK_Offline_Installer/cell"
else
    echo "ERROR: Could not find cell/ directory in SDK"
    exit 1
fi

echo "Using SDK at: $CELL_DIR"

# Build Docker image with SDK
echo ""
echo "Building Docker image with Sony SDK 475.001..."
docker build -t ps3xpad-sony -f "$PROJECT_DIR/Dockerfile.sony" \
    --build-arg SDK_TARBALL="$SDK_TARBALL" \
    --secret id=sdk,src="$SDK_DIR" \
    "$PROJECT_DIR" 2>&1 | tail -20

# Build the plugin
echo ""
echo "Building xpad.sprx..."
docker run --rm \
    -v "$CELL_DIR:/sdk/cell:ro" \
    -v "$PROJECT_DIR:/work" \
    -w /work \
    ps3xpad-sony \
    make -C src -j12

# Verify output
if [ -f "$SDK_IMAGE" ]; then
    SIZE=$(stat -c '%s' "$SDK_IMAGE")
    echo ""
    echo "=== Build complete! ==="
    echo "Output: $SDK_IMAGE ($SIZE bytes)"
    echo ""
    echo "To install on PS3:"
    echo "  1. Copy $SDK_IMAGE to /dev_hdd0/plugins/xpad.sprx"
    echo "  2. Add to /dev_hdd0/boot_plugins.txt:"
    echo "     /dev_hdd0/plugins/xpad.sprx"
    echo "  3. Reboot PS3"
else
    echo ""
    echo "ERROR: xpad.sprx was not produced"
    exit 1
fi
