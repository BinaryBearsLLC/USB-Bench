#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
INFO_PLIST="$PROJECT_ROOT/Packaging/Info.plist"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")"
GET_INFO="$(/usr/bin/plutil -extract CFBundleGetInfoString raw -o - "$INFO_PLIST")"

fail() {
  echo "Version verification failed: $1" >&2
  exit 1
}

[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "invalid semantic version: $VERSION"
[[ "$BUILD_NUMBER" =~ '^[1-9][0-9]*$' ]] || fail "invalid build number: $BUILD_NUMBER"
[[ "$GET_INFO" == *"$VERSION"* ]] || fail "CFBundleGetInfoString is stale"
grep -Fq "## $VERSION" "$PROJECT_ROOT/CHANGELOG.md" || fail "CHANGELOG.md is stale"
grep -Fq "\"softwareVersion\": \"$VERSION\"" "$PROJECT_ROOT/docs/index.html" \
  || fail "structured website version is stale"
grep -Fq "const FALLBACK_VERSION = \"v$VERSION\";" "$PROJECT_ROOT/docs/index.html" \
  || fail "website fallback version is stale"

echo "Version metadata verified: $VERSION ($BUILD_NUMBER)"
