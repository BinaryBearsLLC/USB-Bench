#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
INFO_PLIST="$PROJECT_ROOT/Packaging/Info.plist"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/dist}"
APP_PATH="${1:-$PROJECT_ROOT/.build/release-package/USB Bench.app}"
DMG_PATH="${2:-$OUTPUT_DIR/USB-Bench-$VERSION-Apple-Silicon.dmg}"
LAYOUT="$PROJECT_ROOT/Packaging/DMG/layout.json"
ITEMS="$PROJECT_ROOT/Packaging/DMG/items.tsv"
WATERMARK="$PROJECT_ROOT/Packaging/DMG/Assets/watermark.png"
ARROW="$PROJECT_ROOT/Packaging/DMG/Assets/arrow.png"
WEBSITE_ICON="$PROJECT_ROOT/Packaging/DMG/Assets/website-icon.png"
BACKGROUND_NAME="binarybears-dmg-background.png"
VOLUME_NAME="USB Bench Installer"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
SIGNING_KEYCHAIN="${SIGNING_KEYCHAIN:-}"

fail() {
  echo "USB Bench DMG: $*" >&2
  exit 1
}

layout_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$LAYOUT"
}

attached=0
stage=""
mount_dir=""
cleanup() {
  if [[ "$attached" -eq 1 && -n "$mount_dir" ]]; then
    hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 \
      || hdiutil detach "$mount_dir" -force -quiet >/dev/null 2>&1 \
      || true
  fi
  if [[ -n "$stage" && -d "$stage" ]]; then
    rm -rf -- "$stage"
  fi
}
trap cleanup EXIT

[[ -d "$APP_PATH" && "$APP_PATH" == *.app ]] || fail "missing app bundle: $APP_PATH"
for required in \
  "$LAYOUT" \
  "$ITEMS" \
  "$WATERMARK" \
  "$ARROW" \
  "$WEBSITE_ICON" \
  "$SCRIPT_DIR/render_dmg_background.swift" \
  "$SCRIPT_DIR/set_file_icon.swift" \
  "$SCRIPT_DIR/configure_dmg.applescript"; do
  [[ -f "$required" ]] || fail "missing component: $required"
done
for command_name in codesign hdiutil osascript plutil shasum xcrun; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing macOS tool: $command_name"
done

stage="$(mktemp -d "${TMPDIR:-/tmp}/usb-bench-dmg.XXXXXX")"
payload="$stage/payload"
resolved_items="$stage/items-resolved.tsv"
rw_dmg="$stage/layout.dmg"
compressed_dmg="$stage/final.dmg"
mount_dir="$stage/mount"
mkdir -p "$payload/.background" "$mount_dir" "$(dirname "$DMG_PATH")"

finder_icon_size="$(layout_value finder.iconSize)"
finder_text_size="$(layout_value finder.textSize)"
window_left="$(layout_value finder.windowBounds.0)"
window_top="$(layout_value finder.windowBounds.1)"
window_right="$(layout_value finder.windowBounds.2)"
window_bottom="$(layout_value finder.windowBounds.3)"

while IFS=$'\t' read -r kind name x y; do
  [[ -n "$kind" && "$kind" != \#* ]] || continue
  target="$payload/$name"
  case "$kind" in
    app)
      ditto "$APP_PATH" "$target"
      ;;
    applications)
      ln -s /Applications "$target"
      ;;
    webloc)
      /usr/bin/plutil -create xml1 "$target"
      /usr/bin/plutil -insert URL -string "https://binarybears.com/" "$target"
      xcrun swift "$SCRIPT_DIR/set_file_icon.swift" \
        "$target" "$WEBSITE_ICON" 70 "$finder_icon_size"
      xcrun SetFile -a E "$target"
      ;;
    *)
      fail "unsupported DMG item: $kind"
      ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$kind" "$name" "$x" "$y" >>"$resolved_items"
done <"$ITEMS"

xcrun swift "$SCRIPT_DIR/render_dmg_background.swift" \
  "$payload/.background/$BACKGROUND_NAME" \
  "$WATERMARK" \
  "$ARROW" \
  "$LAYOUT"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$payload" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$rw_dmg" >/dev/null
hdiutil attach "$rw_dmg" \
  -mountpoint "$mount_dir" \
  -readwrite \
  -noverify \
  -noautoopen \
  -nobrowse >/dev/null
attached=1

osascript "$SCRIPT_DIR/configure_dmg.applescript" \
  "$mount_dir" \
  "$resolved_items" \
  "$BACKGROUND_NAME" \
  "$window_left" \
  "$window_top" \
  "$window_right" \
  "$window_bottom" \
  "$finder_icon_size" \
  "$finder_text_size" \
  2
[[ -f "$mount_dir/.DS_Store" ]] || fail "Finder did not persist the layout"

icon_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
if [[ -n "$icon_name" ]]; then
  [[ "$icon_name" == *.icns ]] || icon_name="$icon_name.icns"
  volume_icon="$APP_PATH/Contents/Resources/$icon_name"
else
  volume_icon="$(find "$APP_PATH/Contents/Resources" -maxdepth 1 -name '*.icns' -print -quit)"
fi
[[ -f "$volume_icon" ]] || fail "the app bundle has no usable volume icon"
ditto "$volume_icon" "$mount_dir/.VolumeIcon.icns"
xcrun SetFile -a C "$mount_dir"

sync
hdiutil detach "$mount_dir" -quiet
attached=0
hdiutil convert "$rw_dmg" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$compressed_dmg" >/dev/null

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  signing_arguments=(--force --sign "$SIGNING_IDENTITY" --timestamp)
  if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    signing_arguments+=(--keychain "$SIGNING_KEYCHAIN")
  fi
  codesign "${signing_arguments[@]}" "$compressed_dmg"
  codesign --verify --verbose=2 "$compressed_dmg"
fi
hdiutil verify "$compressed_dmg" >/dev/null

temporary_output="$DMG_PATH.new"
ditto "$compressed_dmg" "$temporary_output"
mv -f "$temporary_output" "$DMG_PATH"
(
  cd "$(dirname "$DMG_PATH")"
  shasum -a 256 "$(basename "$DMG_PATH")" >"$(basename "$DMG_PATH").sha256"
  shasum -a 256 -c "$(basename "$DMG_PATH").sha256"
)

echo "$DMG_PATH"
echo "$DMG_PATH.sha256"
