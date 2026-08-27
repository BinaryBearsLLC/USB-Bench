#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
INFO_PLIST="$PROJECT_ROOT/Packaging/Info.plist"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")"
EXPECTED_BUNDLE_ID="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$INFO_PLIST")"
DMG_PATH="${1:-$PROJECT_ROOT/dist/USB-Bench-$VERSION-Apple-Silicon.dmg}"
REQUIRE_NOTARIZATION="${REQUIRE_NOTARIZATION:-0}"
EXPECTED_TEAM_ID="${EXPECTED_TEAM_ID:-}"
ITEMS="$PROJECT_ROOT/Packaging/DMG/items.tsv"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/usb-bench-mount.XXXXXX")"

fail() {
  echo "Release verification failed: $1" >&2
  exit 1
}

cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 \
    || hdiutil detach "$MOUNT_DIR" -force -quiet >/dev/null 2>&1 \
    || true
  rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

[[ -f "$DMG_PATH" ]] || fail "missing DMG: $DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null
hdiutil attach "$DMG_PATH" \
  -readonly \
  -nobrowse \
  -noautoopen \
  -mountpoint "$MOUNT_DIR" >/dev/null

APP_PATH="$MOUNT_DIR/USB Bench.app"
APP_INFO="$APP_PATH/Contents/Info.plist"
[[ -d "$APP_PATH" ]] || fail "USB Bench.app is missing"
[[ -L "$MOUNT_DIR/Applications" ]] || fail "Applications symlink is missing"
[[ "$(readlink "$MOUNT_DIR/Applications")" == "/Applications" ]] \
  || fail "Applications symlink has an unexpected destination"
[[ -f "$MOUNT_DIR/.DS_Store" ]] || fail "Finder layout is missing"
[[ -f "$MOUNT_DIR/.VolumeIcon.icns" ]] || fail "volume icon is missing"
[[ -f "$MOUNT_DIR/.background/binarybears-dmg-background.png" ]] \
  || fail "DMG background is missing"

website_name="$(awk -F $'\t' '$1 == "webloc" { print $2; exit }' "$ITEMS")"
[[ -n "$website_name" && -f "$MOUNT_DIR/$website_name" ]] \
  || fail "BinaryBears website link is missing"
[[ "$(/usr/bin/plutil -extract URL raw -o - "$MOUNT_DIR/$website_name")" == "https://binarybears.com/" ]] \
  || fail "BinaryBears website link has an unexpected URL"

plutil -lint "$APP_INFO" >/dev/null
[[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$APP_INFO")" == "$EXPECTED_BUNDLE_ID" ]] \
  || fail "bundle identifier mismatch"
[[ "$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$APP_INFO")" == "$VERSION" ]] \
  || fail "application version mismatch"
[[ "$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$APP_INFO")" == "$BUILD_NUMBER" ]] \
  || fail "application build number mismatch"
[[ -f "$APP_PATH/Contents/Resources/BinaryBears-Logo.png" ]] \
  || fail "company logo resource is missing"

codesign --verify --deep --strict --verbose=3 "$APP_PATH"
[[ "$(lipo -archs "$APP_PATH/Contents/MacOS/USBBench")" == "arm64" ]] \
  || fail "the executable is not arm64-only"
otool -L "$APP_PATH/Contents/MacOS/USBBench"

if [[ -n "$EXPECTED_TEAM_ID" ]]; then
  actual_team_id="$(codesign --display --verbose=4 "$APP_PATH" 2>&1 | awk -F= '$1 == "TeamIdentifier" { print $2; exit }')"
  [[ "$actual_team_id" == "$EXPECTED_TEAM_ID" ]] || fail "Developer ID team mismatch"
fi

if [[ "$REQUIRE_NOTARIZATION" == "1" ]]; then
  xcrun stapler validate "$APP_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
  spctl \
    --assess \
    --type open \
    --context context:primary-signature \
    --verbose=2 \
    "$DMG_PATH"
fi

checksum_path="$DMG_PATH.sha256"
if [[ -f "$checksum_path" ]]; then
  (
    cd "${DMG_PATH:h}"
    shasum -a 256 -c "${checksum_path:t}"
  )
fi

echo "Release artifact verified: $DMG_PATH"
