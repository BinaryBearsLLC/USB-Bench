#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
ICON_MASTER="$PROJECT_ROOT/Assets/USB-Bench-Icon.png"
WEB_ICON="$PROJECT_ROOT/docs/assets/usb-bench-icon.png"

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

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/usb-bench-brand.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

sips -z 256 256 "$ICON_MASTER" --out "$TEMP_DIR/usb-bench-icon.png" >/dev/null
cmp -s "$TEMP_DIR/usb-bench-icon.png" "$WEB_ICON" ||
  fail "run scripts/sync_brand_assets.sh after changing the canonical icon"

echo "Brand assets verified"
