#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
ICON_MASTER="$PROJECT_ROOT/Assets/USB-Bench-Icon.png"
WEB_ICON="$PROJECT_ROOT/docs/assets/usb-bench-icon.png"

if [[ ! -f "$ICON_MASTER" ]]; then
  echo "Missing canonical icon: $ICON_MASTER" >&2
  exit 1
fi

mkdir -p "${WEB_ICON:h}"
sips -z 256 256 "$ICON_MASTER" --out "$WEB_ICON" >/dev/null

"$SCRIPT_DIR/verify_brand_assets.sh"
echo "Synchronized website icon from Assets/USB-Bench-Icon.png"
