#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
INFO_PLIST="$PROJECT_ROOT/Packaging/Info.plist"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/dist}"
DMG_PATH="$OUTPUT_DIR/USB-Bench-$VERSION-Apple-Silicon.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-BinaryBears-Notary}"
NOTARY_KEYCHAIN="${NOTARY_KEYCHAIN:-${SIGNING_KEYCHAIN:-}}"

if [[ -z "${SIGNING_IDENTITY:-}" || "$SIGNING_IDENTITY" == "-" ]]; then
  print -u2 "Set SIGNING_IDENTITY to the Developer ID Application certificate."
  exit 2
fi

OUTPUT_DIR="$OUTPUT_DIR" \
SIGNING_IDENTITY="$SIGNING_IDENTITY" \
  "$PROJECT_ROOT/scripts/package_app.sh"

notary_arguments=(--keychain-profile "$NOTARY_PROFILE")
if [[ -n "$NOTARY_KEYCHAIN" ]]; then
  notary_arguments+=(--keychain "$NOTARY_KEYCHAIN")
fi
xcrun notarytool submit "$DMG_PATH" "${notary_arguments[@]}" --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl \
  --assess \
  --type open \
  --context context:primary-signature \
  --verbose=2 \
  "$DMG_PATH"

(
  cd "$OUTPUT_DIR"
  /usr/bin/shasum -a 256 "${DMG_PATH:t}" > "${DMG_PATH:t}.sha256"
)

echo "$DMG_PATH"
echo "$DMG_PATH.sha256"
