#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$PROJECT_ROOT/Packaging/Info.plist")"
DMG_PATH="${1:-$PROJECT_ROOT/dist/USB-Bench-$VERSION-Apple-Silicon.dmg}"
MOUNT_DIR="$(mktemp -d "${TMPDIR%/}/usb-bench-mount.XXXXXX")"

cleanup() {
  if mount | grep -Fq "on $MOUNT_DIR "; then
    hdiutil detach "$MOUNT_DIR" >/dev/null
  fi
  rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

hdiutil verify "$DMG_PATH"
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR"
test -d "$MOUNT_DIR/USB Bench.app"
test -L "$MOUNT_DIR/Applications"
plutil -lint "$MOUNT_DIR/USB Bench.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=3 "$MOUNT_DIR/USB Bench.app"
test "$(lipo -archs "$MOUNT_DIR/USB Bench.app/Contents/MacOS/USBBench")" = "arm64"
otool -L "$MOUNT_DIR/USB Bench.app/Contents/MacOS/USBBench"
