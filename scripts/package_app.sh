#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/dist}"
BUILD_ROOT="${BUILD_ROOT:-$PROJECT_ROOT/.build/release-package}"
MODULE_CACHE="${MODULE_CACHE:-$PROJECT_ROOT/.build/module-cache}"
SWIFT_CACHE="${SWIFT_CACHE:-$PROJECT_ROOT/.build/swift-cache}"
SWIFTPM_SCRATCH="${SWIFTPM_SCRATCH:-$PROJECT_ROOT/.build/swiftpm-release}"
APP_NAME="USB Bench"
EXECUTABLE_NAME="USBBench"
INFO_PLIST="$PROJECT_ROOT/Packaging/Info.plist"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
APP_PATH="$BUILD_ROOT/$APP_NAME.app"
DMG_PATH="$OUTPUT_DIR/USB-Bench-$VERSION-Apple-Silicon.dmg"
ICON_MASTER="$PROJECT_ROOT/Assets/USB-Bench-Icon.png"
ICONSET_PATH="$BUILD_ROOT/AppIcon.iconset"
ASSET_CATALOG="$BUILD_ROOT/IconAssets.xcassets"
ASSET_OUTPUT="$BUILD_ROOT/compiled-assets"

mkdir -p "$OUTPUT_DIR" "$BUILD_ROOT" "$MODULE_CACHE" "$SWIFT_CACHE"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFT_MODULECACHE_PATH="$SWIFT_CACHE"

swift build \
  --disable-sandbox \
  --configuration release \
  --arch arm64 \
  --scratch-path "$SWIFTPM_SCRATCH"

BIN_PATH="$(swift build \
  --disable-sandbox \
  --configuration release \
  --arch arm64 \
  --scratch-path "$SWIFTPM_SCRATCH" \
  --show-bin-path)"

rm -rf "$APP_PATH" "$ICONSET_PATH" "$ASSET_CATALOG" "$ASSET_OUTPUT"
mkdir -p \
  "$APP_PATH/Contents/MacOS" \
  "$APP_PATH/Contents/Resources" \
  "$ICONSET_PATH" \
  "$ASSET_CATALOG/AppIcon.appiconset" \
  "$ASSET_OUTPUT"

ditto "$BIN_PATH/$EXECUTABLE_NAME" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
chmod 755 "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
ditto "$PROJECT_ROOT/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
ditto "$PROJECT_ROOT/Packaging/PkgInfo" "$APP_PATH/Contents/PkgInfo"

sips -z 16 16 "$ICON_MASTER" --out "$ICONSET_PATH/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_MASTER" --out "$ICONSET_PATH/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_MASTER" --out "$ICONSET_PATH/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_MASTER" --out "$ICONSET_PATH/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_MASTER" --out "$ICONSET_PATH/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_MASTER" --out "$ICONSET_PATH/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_MASTER" --out "$ICONSET_PATH/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_MASTER" --out "$ICONSET_PATH/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_MASTER" --out "$ICONSET_PATH/icon_512x512.png" >/dev/null
ditto "$ICON_MASTER" "$ICONSET_PATH/icon_512x512@2x.png"
ditto "$ICONSET_PATH" "$ASSET_CATALOG/AppIcon.appiconset"
ditto "$PROJECT_ROOT/Packaging/AppIconContents.json" "$ASSET_CATALOG/AppIcon.appiconset/Contents.json"
xcrun actool \
  --compile "$ASSET_OUTPUT" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$BUILD_ROOT/asset-info.plist" \
  "$ASSET_CATALOG"
ditto "$ASSET_OUTPUT/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

plutil -lint "$APP_PATH/Contents/Info.plist"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --sign - --timestamp=none "$APP_PATH"
else
  codesign \
    --force \
    --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    "$APP_PATH"
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

DMG_STAGE="$(mktemp -d "$BUILD_ROOT/dmg-stage.XXXXXX")"
trap 'rm -rf "$DMG_STAGE"' EXIT
ditto "$APP_PATH" "$DMG_STAGE/$APP_NAME.app"
ln -s /Applications "$DMG_STAGE/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG_PATH"
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi
hdiutil verify "$DMG_PATH"

echo "$APP_PATH"
echo "$DMG_PATH"
