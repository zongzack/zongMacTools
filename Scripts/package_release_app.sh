#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="zongMacTools"
INFO_PLIST="$ROOT_DIR/Sources/DockHoverPreviewProbe/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
DIST_DIR="$ROOT_DIR/dist/zongMacTools-${VERSION}-${BUILD_NUMBER}"
APP_COPY_DIR="$DIST_DIR/${APP_NAME}.app"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-${BUILD_NUMBER}.zip"
METADATA_PATH="$DIST_DIR/release-metadata.txt"

mkdir -p "$ROOT_DIR/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

APP_PATH="$(CONFIGURATION="$CONFIGURATION" "$ROOT_DIR/Scripts/build_probe_app.sh")"
"$ROOT_DIR/Scripts/verify_app_bundle.sh" "$APP_PATH" >&2

cp -R "$APP_PATH" "$APP_COPY_DIR"
cat > "$DIST_DIR/README-install.txt" <<EOF
zongMacTools ${VERSION} (${BUILD_NUMBER})

Install by copying zongMacTools.app to /Applications, then grant Accessibility and Screen Recording permissions in System Settings.
If this build is ad-hoc signed, macOS may require re-adding those permissions after each rebuild.
EOF

(
  cd "$DIST_DIR"
  ditto -c -k --keepParent "${APP_NAME}.app" "$ZIP_PATH"
)

ARCHIVE_VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zongMacTools-release-verify.XXXXXX")"
trap 'rm -rf "$ARCHIVE_VERIFY_DIR"' EXIT
ditto -x -k "$ZIP_PATH" "$ARCHIVE_VERIFY_DIR"
"$ROOT_DIR/Scripts/verify_app_bundle.sh" "$ARCHIVE_VERIFY_DIR/${APP_NAME}.app" >&2

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > SHA256SUMS.txt
)

SIGNING_MODE="$(codesign -dv --verbose=4 "$APP_COPY_DIR" 2>&1 | awk -F= '/Signature=/{print $2; exit}')"
GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
CHECKSUM="$(awk '{print $1}' "$DIST_DIR/SHA256SUMS.txt")"
NOTARIZATION_STATUS="skipped"

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait > "$DIST_DIR/notary-log.txt"
  NOTARIZATION_STATUS="submitted"
else
  echo "package_release_app: NOTARYTOOL_PROFILE not set; skipping notarization." >&2
fi

cat > "$METADATA_PATH" <<EOF
app=${APP_NAME}
version=${VERSION}
build=${BUILD_NUMBER}
configuration=${CONFIGURATION}
gitCommit=${GIT_COMMIT}
signingMode=${SIGNING_MODE:-unknown}
artifact=$(basename "$ZIP_PATH")
sha256=${CHECKSUM}
verification=Scripts/verify_app_bundle.sh build/zongMacTools.app
notarizationStatus=${NOTARIZATION_STATUS}
EOF

echo "$DIST_DIR"
