#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
ICON_MASTER="$PROJECT_ROOT/Assets/USB-Bench-Icon.png"
WEB_ICON="$PROJECT_ROOT/docs/assets/usb-bench-icon.png"
COMPANY_LOGO="$PROJECT_ROOT/Assets/BinaryBears-Logo.png"
DMG_WATERMARK="$PROJECT_ROOT/Packaging/DMG/Assets/watermark.png"
DMG_ARROW="$PROJECT_ROOT/Packaging/DMG/Assets/arrow.png"
DMG_WEBSITE_ICON="$PROJECT_ROOT/Packaging/DMG/Assets/website-icon.png"

fail() {
  echo "Brand asset verification failed: $1" >&2
  exit 1
}

image_property() {
  local image_path="$1"
  local property="$2"

  sips -g "$property" "$image_path" 2>/dev/null |
    awk -v key="$property:" '$1 == key { print $2 }'
}

[[ -f "$ICON_MASTER" ]] || fail "missing Assets/USB-Bench-Icon.png"
[[ -f "$WEB_ICON" ]] || fail "missing docs/assets/usb-bench-icon.png"
[[ -f "$COMPANY_LOGO" ]] || fail "missing Assets/BinaryBears-Logo.png"
[[ -f "$DMG_WATERMARK" ]] || fail "missing DMG watermark"
[[ -f "$DMG_ARROW" ]] || fail "missing DMG arrow"
[[ -f "$DMG_WEBSITE_ICON" ]] || fail "missing DMG website icon"

[[ "$(image_property "$ICON_MASTER" pixelWidth)" == "1024" ]] ||
  fail "the canonical icon must be 1024 pixels wide"
[[ "$(image_property "$ICON_MASTER" pixelHeight)" == "1024" ]] ||
  fail "the canonical icon must be 1024 pixels high"
[[ "$(image_property "$ICON_MASTER" format)" == "png" ]] ||
  fail "the canonical icon must be a PNG"

[[ "$(image_property "$WEB_ICON" pixelWidth)" == "256" ]] ||
  fail "the website icon must be 256 pixels wide"
[[ "$(image_property "$WEB_ICON" pixelHeight)" == "256" ]] ||
  fail "the website icon must be 256 pixels high"
[[ "$(image_property "$WEB_ICON" format)" == "png" ]] ||
  fail "the website icon must be a PNG"

[[ "$(image_property "$COMPANY_LOGO" pixelWidth)" == "256" ]] ||
  fail "the company logo must be 256 pixels wide"
[[ "$(image_property "$COMPANY_LOGO" pixelHeight)" == "256" ]] ||
  fail "the company logo must be 256 pixels high"
[[ "$(image_property "$COMPANY_LOGO" hasAlpha)" == "yes" ]] ||
  fail "the company logo must preserve transparency"

for raster in "$COMPANY_LOGO" "$DMG_WATERMARK" "$DMG_ARROW" "$DMG_WEBSITE_ICON"; do
  [[ "$(image_property "$raster" format)" == "png" ]] ||
    fail "$raster must be a PNG"
  [[ "$(image_property "$raster" hasAlpha)" == "yes" ]] ||
    fail "$raster must use an alpha channel"
  if strings "$raster" | grep -E -i '/Users/|Inkscape|<script|<svg|javascript:' >/dev/null; then
    fail "$raster contains source or personal metadata"
  fi
done

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/usb-bench-brand.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

sips -z 256 256 "$ICON_MASTER" --out "$TEMP_DIR/usb-bench-icon.png" >/dev/null
cmp -s "$TEMP_DIR/usb-bench-icon.png" "$WEB_ICON" ||
  fail "run scripts/sync_brand_assets.sh after changing the canonical icon"

echo "Brand assets verified"
