#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
QUALITY_CACHE_ROOT="$PROJECT_ROOT/.build/quality-cache"

cd "$PROJECT_ROOT"
mkdir -p \
  "$QUALITY_CACHE_ROOT/clang" \
  "$QUALITY_CACHE_ROOT/swift"

export CLANG_MODULE_CACHE_PATH="$QUALITY_CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$QUALITY_CACHE_ROOT/swift"

swift format lint --recursive --parallel --strict \
  Sources Tests Package.swift

plutil -lint Packaging/Info.plist
zsh -n \
  scripts/check_all.sh \
  scripts/notarize_release.sh \
  scripts/package_app.sh \
  scripts/sync_brand_assets.sh \
  scripts/verify_brand_assets.sh \
  scripts/verify_release.sh
./scripts/verify_brand_assets.sh

swift test \
  --disable-sandbox \
  --scratch-path "$QUALITY_CACHE_ROOT/swiftpm-tests"
./scripts/package_app.sh
./scripts/verify_release.sh

echo "All local quality gates passed."
