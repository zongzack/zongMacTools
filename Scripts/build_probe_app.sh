#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXECUTABLE_NAME="DockHoverPreviewProbe"
APP_BUNDLE_NAME="zongMacTools"
CONFIGURATION="${CONFIGURATION:-debug}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_DIR="$ROOT_DIR/build/${APP_BUNDLE_NAME}.app"
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

CODE_SIGN_OPTIONS=()
if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  echo "Signing with ad-hoc identity (-)." >&2
  echo "TCC caveat: ad-hoc re-signing can require re-adding Accessibility and Screen Recording permissions." >&2
  codesign --force --sign "$CODE_SIGN_IDENTITY" --entitlements "$EXTENSION_ENTITLEMENTS_PATH" "$EXTENSION_DIR" >&2
  codesign --force --sign "$CODE_SIGN_IDENTITY" "$APP_DIR" >&2
else
  CODE_SIGN_OPTIONS+=(--options runtime --timestamp)
  echo "Signing with configured identity: $CODE_SIGN_IDENTITY" >&2
  codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODE_SIGN_OPTIONS[@]}" --entitlements "$EXTENSION_ENTITLEMENTS_PATH" "$EXTENSION_DIR" >&2
  codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODE_SIGN_OPTIONS[@]}" "$APP_DIR" >&2
fi

codesign --verify --strict "$EXTENSION_DIR" >&2
codesign --verify --deep --strict "$APP_DIR" >&2
codesign -dv --verbose=4 "$APP_DIR" >&2

echo "$APP_DIR"
