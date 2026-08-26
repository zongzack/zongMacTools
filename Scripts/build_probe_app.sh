#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXECUTABLE_NAME="DockHoverPreviewProbe"
APP_BUNDLE_NAME="zongMacTools"
CONFIGURATION="${CONFIGURATION:-debug}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_DIR="$ROOT_DIR/build/${APP_BUNDLE_NAME}.app"
SIGNING_TRACE_PATH="${SIGNING_TRACE_PATH:-$ROOT_DIR/build/signing-order.log}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLUGINS_DIR="$CONTENTS_DIR/PlugIns"
EXTENSION_BUNDLE_NAME="FinderSyncExtension.appex"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" >&2
EXECUTABLE_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)/$EXECUTABLE_NAME"
EXTENSION_EXECUTABLE_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)/FinderSyncExtension"
SWIFT_BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
CORE_RESOURCE_BUNDLE="$SWIFT_BIN_DIR/DockHoverPreviewProbe_FinderNewFileCore.bundle"
EXTENSION_ENTITLEMENTS_PATH="$ROOT_DIR/Sources/FinderSyncExtension/FinderSyncExtension.entitlements"

[[ -d "$CORE_RESOURCE_BUNDLE" ]] || { echo "missing FinderNewFileCore resource bundle: $CORE_RESOURCE_BUNDLE" >&2; exit 1; }

mkdir -p "$(dirname "$SIGNING_TRACE_PATH")"
: > "$SIGNING_TRACE_PATH"
printf '%s\n' "build configuration=$CONFIGURATION" >> "$SIGNING_TRACE_PATH"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$PLUGINS_DIR/$EXTENSION_BUNDLE_NAME/Contents/MacOS" "$PLUGINS_DIR/$EXTENSION_BUNDLE_NAME/Contents/Resources"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Sources/DockHoverPreviewProbe/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

EXTENSION_DIR="$PLUGINS_DIR/$EXTENSION_BUNDLE_NAME"
cp "$EXTENSION_EXECUTABLE_PATH" "$EXTENSION_DIR/Contents/MacOS/FinderSyncExtension"
cp "$ROOT_DIR/Sources/FinderSyncExtension/Info.plist" "$EXTENSION_DIR/Contents/Info.plist"
chmod +x "$EXTENSION_DIR/Contents/MacOS/FinderSyncExtension"
cp -R "$CORE_RESOURCE_BUNDLE" "$EXTENSION_DIR/Contents/Resources/"

ICON_SOURCE="$ROOT_DIR/Assets/AppIcon/zong-mac-tools-logo.png"
cp "$ICON_SOURCE" "$RESOURCES_DIR/zong-mac-tools-logo.png"
ICONSET_DIR="$ROOT_DIR/build/zongMacTools.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/zongMacTools.icns"
rm -rf "$ICONSET_DIR"

plutil -lint "$CONTENTS_DIR/Info.plist" >&2
plutil -lint "$EXTENSION_DIR/Contents/Info.plist" >&2

if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  echo "Signing with ad-hoc identity (-)." >&2
  echo "TCC caveat: ad-hoc re-signing can require re-adding Accessibility and Screen Recording permissions." >&2
else
  echo "Signing with configured identity: $CODE_SIGN_IDENTITY" >&2
fi

sign_code() {
  local target="$1"
  shift
  if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
codesign --force --sign "$CODE_SIGN_IDENTITY" "$@" "$target" >&2
  else
codesign --force --sign "$CODE_SIGN_IDENTITY" --options runtime --timestamp "$@" "$target" >&2
  fi
}

printf '%s\n' "1 extension-sign start" >> "$SIGNING_TRACE_PATH"
sign_code "$EXTENSION_DIR" --entitlements "$EXTENSION_ENTITLEMENTS_PATH"
printf '%s\n' "2 extension-sign success" >> "$SIGNING_TRACE_PATH"
printf '%s\n' "3 app-sign start" >> "$SIGNING_TRACE_PATH"
sign_code "$APP_DIR"
printf '%s\n' "4 app-sign success" >> "$SIGNING_TRACE_PATH"
APP_CDHASH="$(codesign -dv --verbose=4 "$APP_DIR" 2>&1 | awk -F= '/^CDHash=/{print $2; exit}')"
EXTENSION_CDHASH="$(codesign -dv --verbose=4 "$EXTENSION_DIR" 2>&1 | awk -F= '/^CDHash=/{print $2; exit}')"
[[ -n "$APP_CDHASH" && -n "$EXTENSION_CDHASH" ]] || { echo "unable to record signed bundle CDHash values" >&2; exit 1; }
printf '%s\n' "artifact app-cdhash=$APP_CDHASH" >> "$SIGNING_TRACE_PATH"
printf '%s\n' "artifact extension-cdhash=$EXTENSION_CDHASH" >> "$SIGNING_TRACE_PATH"
printf '%s\n' "5 extension-verify start" >> "$SIGNING_TRACE_PATH"
codesign --verify --strict "$EXTENSION_DIR" >&2
printf '%s\n' "6 extension-verify success" >> "$SIGNING_TRACE_PATH"
printf '%s\n' "7 app-verify start" >> "$SIGNING_TRACE_PATH"
codesign --verify --strict "$APP_DIR" >&2
printf '%s\n' "8 app-verify success" >> "$SIGNING_TRACE_PATH"
codesign -dv --verbose=4 "$APP_DIR" >&2

echo "$APP_DIR"
