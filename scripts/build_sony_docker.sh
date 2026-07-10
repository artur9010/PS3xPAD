#!/usr/bin/env bash
# Build script for PS3xPAD using the Sony PS3 SDK 4.00 via wine
# Direct compilation without relying on Sony SDK's makefile system
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# SDK paths
export CELL_SDK=/sdk/cell
export PATH=$CELL_SDK/host-win32/ppu/bin:$CELL_SDK/host-win32/bin:$CELL_SDK/host-win32/sn/bin:$PATH
export PS3=/data
export WINEDEBUG=-all
export WINEPREFIX=/root/.wine

echo "=== PS3xPAD Sony SDK 4.00 Build ==="
echo "SDK: $CELL_SDK"
echo "Keys: $PS3/keys"
echo ""

# Initialize wine if needed
if [ ! -d "$WINEPREFIX" ]; then
    wineboot --init 2>/dev/null || true
fi

# Verify SDK
if [ ! -f "$CELL_SDK/host-win32/ppu/bin/ppu-lv2-gcc.exe" ]; then
    echo "ERROR: ppu-lv2-gcc.exe not found"
    exit 1
fi

# Check keys
if [ ! -f "$PS3/keys" ]; then
    echo "ERROR: keys file not found at $PS3/keys"
    exit 1
fi

# Create wine wrapper for ppu-lv2-gcc
cat > /tmp/ppu-lv2-gcc << 'EOF'
#!/bin/bash
exec wine /sdk/cell/host-win32/ppu/bin/ppu-lv2-gcc.exe "$@"
EOF
chmod +x /tmp/ppu-lv2-gcc

# Create wine wrapper for ppu-lv2-g++
cat > /tmp/ppu-lv2-g++ << 'EOF'
#!/bin/bash
exec wine /sdk/cell/host-win32/ppu/bin/ppu-lv2-g++.exe "$@"
EOF
chmod +x /tmp/ppu-lv2-g++

# Create wine wrapper for ppu-lv2-prx-strip
cat > /tmp/ppu-lv2-prx-strip << 'EOF'
#!/bin/bash
exec wine /sdk/cell/host-win32/bin/ppu-lv2-prx-strip.exe "$@"
EOF
chmod +x /tmp/ppu-lv2-prx-strip

# Create wine wrapper for ppu-lv2-ar
cat > /tmp/ppu-lv2-ar << 'EOF'
#!/bin/bash
exec wine /sdk/cell/host-win32/ppu/bin/ppu-lv2-ar.exe "$@"
EOF
chmod +x /tmp/ppu-lv2-ar

# Create wine wrapper for ppu-lv2-ranlib
cat > /tmp/ppu-lv2-ranlib << 'EOF'
#!/bin/bash
exec wine /sdk/cell/host-win32/ppu/bin/ppu-lv2-ranlib.exe "$@"
EOF
chmod +x /tmp/ppu-lv2-ranlib

export PATH=/tmp:$PATH

if [ ! -x /opt/oscetool/oscetool ]; then
    echo "ERROR: oscetool not found at /opt/oscetool/oscetool"
    exit 1
fi

if [ ! -f "$PS3/ldr_curves" ]; then
    echo "ERROR: loader curves file not found at $PS3/ldr_curves"
    exit 1
fi

echo "=== Building PRX/SPRX with SDK makefiles ==="
make -C "$PROJECT_DIR/src" \
    CELL_MK_DIR=/sdk/sdk192/PS3_SDK_v1.92-FuxSony/samples/mk \
    CELL_SDK="$CELL_SDK" \
    CELL_TARGET_PATH="$CELL_SDK/target" \
    CELL_HOST_PATH="$CELL_SDK/host-win32" \
    CELL_HOST_BIN_PATH="$CELL_SDK/host-win32/bin" \
    clean
make -C "$PROJECT_DIR/src" \
    CELL_MK_DIR=/sdk/sdk192/PS3_SDK_v1.92-FuxSony/samples/mk \
    CELL_SDK="$CELL_SDK" \
    CELL_TARGET_PATH="$CELL_SDK/target" \
    CELL_HOST_PATH="$CELL_SDK/host-win32" \
    CELL_HOST_BIN_PATH="$CELL_SDK/host-win32/bin" \
    xpad.prx

echo "=== Stripping PRX ==="
cd "$PROJECT_DIR/src"
ppu-lv2-prx-strip --strip-debug --strip-section-header xpad.prx

echo "=== Signing SPRX ==="
/opt/oscetool/oscetool -0 SELF -1 TRUE -s FALSE -2 1C \
    -3 1070000052000001 \
    -4 01000002 \
    -5 APP \
    -6 0003004000000000 \
    -A 0001000000000000 \
    -e xpad.prx xpad.sprx 2>&1

# Check output
if [ -f xpad.sprx ]; then
    echo ""
    echo "=== BUILD SUCCESSFUL ==="
    ls -la xpad.sprx
    echo ""
    echo "Output: $PROJECT_DIR/src/xpad.sprx"
else
    echo ""
    echo "=== BUILD FAILED ==="
    ls -la xpad.prx 2>/dev/null
    echo "PRX was built but SPRX signing failed"
    exit 1
fi
