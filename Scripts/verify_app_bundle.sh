#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/zongMacTools.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/DockHoverPreviewProbe"
ICON_PATH="$APP_PATH/Contents/Resources/zongMacTools.icns"
PLUGINS_DIR="$APP_PATH/Contents/PlugIns"

fail() {
  echo "verify_app_bundle: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

[[ -d "$APP_PATH" ]] || fail "missing app bundle: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "path is not an .app bundle: $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "missing Info.plist"
[[ -x "$EXECUTABLE_PATH" ]] || fail "missing executable: $EXECUTABLE_PATH"
[[ -f "$ICON_PATH" ]] || fail "missing icon: $ICON_PATH"

FINDER_EXTENSIONS=()
while IFS= read -r extension_path; do
  FINDER_EXTENSIONS+=("$extension_path")
done < <(find "$PLUGINS_DIR" -maxdepth 1 -type d -name '*.appex' -print)
[[ "${#FINDER_EXTENSIONS[@]}" -eq 1 ]] || fail "expected exactly one embedded extension"
EXTENSION_PATH="${FINDER_EXTENSIONS[0]}"
EXTENSION_INFO_PLIST="$EXTENSION_PATH/Contents/Info.plist"
EXTENSION_EXECUTABLE_PATH="$EXTENSION_PATH/Contents/MacOS/FinderSyncExtension"
[[ -f "$EXTENSION_INFO_PLIST" ]] || fail "missing Finder Sync extension Info.plist"
[[ -x "$EXTENSION_EXECUTABLE_PATH" ]] || fail "missing Finder Sync extension executable"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$EXTENSION_INFO_PLIST")" == "com.apple.FinderSync" ]] || fail "Finder Sync extension point mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXTENSION_INFO_PLIST")" == "com.zong.zongMacTools.finder-sync" ]] || fail "Finder Sync extension bundle id mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPrincipalClass' "$EXTENSION_INFO_PLIST")" == "FinderSyncExtension.FinderSyncExtension" ]] || fail "Finder Sync principal class mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$EXTENSION_INFO_PLIST")" == "$(plist_value LSMinimumSystemVersion)" ]] || fail "minimum system version mismatch"
[[ "$(lipo -archs "$EXECUTABLE_PATH")" == "$(lipo -archs "$EXTENSION_EXECUTABLE_PATH")" ]] || fail "main app and extension architectures differ"

[[ "$(plist_value CFBundleExecutable)" == "DockHoverPreviewProbe" ]] || fail "CFBundleExecutable mismatch"
[[ "$(plist_value CFBundleIdentifier)" == "com.zong.zongMacTools" ]] || fail "CFBundleIdentifier mismatch"
[[ "$(plist_value CFBundleName)" == "zongMacTools" ]] || fail "CFBundleName mismatch"
[[ "$(plist_value CFBundleDisplayName)" == "zongMacTools" ]] || fail "CFBundleDisplayName mismatch"
[[ "$(plist_value CFBundleIconFile)" == "zongMacTools" ]] || fail "CFBundleIconFile mismatch"

codesign --verify --deep --strict "$APP_PATH" >&2
codesign --verify --strict "$EXTENSION_PATH" >&2
SIGNING_SUMMARY="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
echo "$SIGNING_SUMMARY" >&2

if grep -qi "Signature=adhoc" <<<"$SIGNING_SUMMARY"; then
  echo "verify_app_bundle: ad-hoc signature detected." >&2
  echo "TCC caveat: ad-hoc re-signing can require re-adding Accessibility and Screen Recording permissions." >&2
fi

echo "verify_app_bundle: OK $APP_PATH" >&2
