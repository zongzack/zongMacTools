#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/zongMacTools.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/DockHoverPreviewProbe"
ICON_PATH="$APP_PATH/Contents/Resources/zongMacTools.icns"
PLUGINS_DIR="$APP_PATH/Contents/PlugIns"
SIGNING_TRACE_PATH="${SIGNING_TRACE_PATH:-$ROOT_DIR/build/signing-order.log}"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zongMacTools-verify.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  echo "verify_app_bundle: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

[[ -d "$APP_PATH" ]] || fail "missing app bundle: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "path is not an .app bundle: $APP_PATH"

# User configuration and imported template bytes live in the account's
# Application Support domain. They must never be copied into the signed app;
# doing so would make the bundle stale and could leak user data into releases.
assert_runtime_path_absent() {
  local kind="$1"
  local name="$2"
  local message="$3"
  if find "$APP_PATH/Contents" -type "$kind" -name "$name" -print -quit | grep -q .; then
    fail "$message"
  fi
}

assert_runtime_path_absent f 'catalog.json' 'runtime catalog.json must not be embedded in the app bundle'
assert_runtime_path_absent d 'Templates' 'runtime Templates directory must not be embedded in the app bundle'

[[ -f "$INFO_PLIST" ]] || fail "missing Info.plist"
[[ -x "$EXECUTABLE_PATH" ]] || fail "missing executable: $EXECUTABLE_PATH"
[[ -f "$ICON_PATH" ]] || fail "missing icon: $ICON_PATH"
[[ -d "$PLUGINS_DIR" ]] || fail "missing PlugIns directory"
FINDER_EXTENSIONS=()
while IFS= read -r extension_path; do
  FINDER_EXTENSIONS+=("$extension_path")
done < <(find "$PLUGINS_DIR" -maxdepth 1 -type d -name '*.appex' -print)
[[ "${#FINDER_EXTENSIONS[@]}" -eq 1 ]] || fail "expected exactly one embedded extension"
EXTENSION_PATH="${FINDER_EXTENSIONS[0]}"
ALL_APPEX_COUNT="$(find "$APP_PATH" -type d -name '*.appex' -print | wc -l | tr -d ' ')"
[[ "$ALL_APPEX_COUNT" -eq 1 ]] || fail "expected exactly one appex in the complete bundle"
EXTENSION_INFO_PLIST="$EXTENSION_PATH/Contents/Info.plist"
EXTENSION_EXECUTABLE_PATH="$EXTENSION_PATH/Contents/MacOS/FinderSyncExtension"
RESOURCE_BUNDLE="$EXTENSION_PATH/Contents/Resources/DockHoverPreviewProbe_FinderNewFileCore.bundle"
[[ -f "$EXTENSION_INFO_PLIST" ]] || fail "missing Finder Sync extension Info.plist"
[[ -x "$EXTENSION_EXECUTABLE_PATH" ]] || fail "missing Finder Sync extension executable"
for template in BlankWord BlankExcel BlankPowerPoint; do
  [[ -f "$RESOURCE_BUNDLE/$template.zip" ]] || fail "missing embedded $template template"
  unzip -tqq "$RESOURCE_BUNDLE/$template.zip" || fail "invalid $template template ZIP"
done

extract_template() {
  local archive="$1"
  local name="$2"
  local destination="$TEMP_DIR/$name"
  mkdir -p "$destination"
  unzip -qq "$archive" -d "$destination" || fail "unable to extract $(basename "$archive")"
  printf '%s\n' "$destination"
}

validate_xml_file() {
  local root="$1"
  local entry="$2"
  [[ -f "$root/$entry" ]] || fail "missing XML entry $entry"
  xmllint --noout --nonet "$root/$entry" >/dev/null || fail "invalid XML entry $entry"
}

WORD_TEMPLATE="$RESOURCE_BUNDLE/BlankWord.zip"
EXCEL_TEMPLATE="$RESOURCE_BUNDLE/BlankExcel.zip"
POWERPOINT_TEMPLATE="$RESOURCE_BUNDLE/BlankPowerPoint.zip"
WORD_ROOT="$(extract_template "$WORD_TEMPLATE" word)"
EXCEL_ROOT="$(extract_template "$EXCEL_TEMPLATE" excel)"
POWERPOINT_ROOT="$(extract_template "$POWERPOINT_TEMPLATE" powerpoint)"
for entry in '[Content_Types].xml' '_rels/.rels' 'word/document.xml'; do
  validate_xml_file "$WORD_ROOT" "$entry"
done
for entry in '[Content_Types].xml' '_rels/.rels' 'xl/workbook.xml' 'xl/_rels/workbook.xml.rels' 'xl/worksheets/sheet1.xml'; do
  validate_xml_file "$EXCEL_ROOT" "$entry"
done
grep -q 'name="Sheet1"' "$EXCEL_ROOT/xl/workbook.xml" || fail "Excel template is missing Sheet1"
for entry in '[Content_Types].xml' '_rels/.rels' 'ppt/presentation.xml' 'ppt/_rels/presentation.xml.rels' 'ppt/slides/slide1.xml'; do
  validate_xml_file "$POWERPOINT_ROOT" "$entry"
done
grep -q '<p:sld' "$POWERPOINT_ROOT/ppt/slides/slide1.xml" || fail "PowerPoint template is missing a slide"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$EXTENSION_INFO_PLIST")" == "com.apple.FinderSync" ]] || fail "Finder Sync extension point mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXTENSION_INFO_PLIST")" == "com.zong.zongMacTools.finder-sync" ]] || fail "Finder Sync extension bundle id mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$EXTENSION_INFO_PLIST")" == "zongMacTools" ]] || fail "Finder Sync display name mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPrincipalClass' "$EXTENSION_INFO_PLIST")" == "FinderSyncExtension.FinderSyncExtension" ]] || fail "Finder Sync principal class mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes' "$EXTENSION_INFO_PLIST" 2>/dev/null)" == "Dict"* ]] || fail "Finder Sync extension attributes missing"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$EXTENSION_INFO_PLIST")" == "$(plist_value LSMinimumSystemVersion)" ]] || fail "minimum system version mismatch"

normalized_arches() {
  lipo -archs "$1" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}
[[ "$(normalized_arches "$EXECUTABLE_PATH")" == "$(normalized_arches "$EXTENSION_EXECUTABLE_PATH")" ]] || fail "main app and extension architectures differ"

[[ "$(plist_value CFBundleExecutable)" == "DockHoverPreviewProbe" ]] || fail "CFBundleExecutable mismatch"
[[ "$(plist_value CFBundleIdentifier)" == "com.zong.zongMacTools" ]] || fail "CFBundleIdentifier mismatch"
[[ "$(plist_value CFBundleName)" == "zongMacTools" ]] || fail "CFBundleName mismatch"
[[ "$(plist_value CFBundleDisplayName)" == "zongMacTools" ]] || fail "CFBundleDisplayName mismatch"
[[ "$(plist_value CFBundleIconFile)" == "zongMacTools" ]] || fail "CFBundleIconFile mismatch"

codesign --verify --strict "$EXTENSION_PATH" >&2
codesign --verify --strict "$APP_PATH" >&2
while IFS= read -r -d '' nested_executable; do
  if file "$nested_executable" | grep -q 'Mach-O'; then
    codesign --verify --strict "$nested_executable" >&2 || fail "nested executable signature invalid: $nested_executable"
  fi
done < <(find "$APP_PATH/Contents" -type f -perm -111 -print0)
SIGNING_SUMMARY="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
EXTENSION_SIGNING_SUMMARY="$(codesign -dv --verbose=4 "$EXTENSION_PATH" 2>&1)"
grep -q 'Identifier=com.zong.zongMacTools.finder-sync' <<<"$EXTENSION_SIGNING_SUMMARY" || fail "extension signature identifier mismatch"

EXTENSION_ENTITLEMENTS="$TEMP_DIR/extension-entitlements.plist"
codesign -d --entitlements :- "$EXTENSION_PATH" > "$EXTENSION_ENTITLEMENTS" 2>/dev/null || fail "unable to read extension entitlements"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$EXTENSION_ENTITLEMENTS" 2>/dev/null || true)" == "true" ]] || fail "extension is not signed with app sandbox entitlement"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.temporary-exception.files.home-relative-path.read-write:0' "$EXTENSION_ENTITLEMENTS" 2>/dev/null || true)" == "/" ]] || fail "extension is missing home-relative read-write temporary exception"

[[ -f "$SIGNING_TRACE_PATH" ]] || fail "missing signing order trace: $SIGNING_TRACE_PATH"
TRACE_CONTENT="$(cat "$SIGNING_TRACE_PATH")"
grep -q '^2 extension-sign success$' <<<"$TRACE_CONTENT" || fail "signing trace is missing successful extension signing"
grep -q '^3 app-sign start$' <<<"$TRACE_CONTENT" || fail "signing trace is missing app signing start"
EXTENSION_SUCCESS_LINE="$(grep -n '^2 extension-sign success$' "$SIGNING_TRACE_PATH" | head -n 1 | cut -d: -f1)"
APP_START_LINE="$(grep -n '^3 app-sign start$' "$SIGNING_TRACE_PATH" | head -n 1 | cut -d: -f1)"
[[ "$EXTENSION_SUCCESS_LINE" -lt "$APP_START_LINE" ]] || fail "signing trace order is invalid"
TRACE_APP_CDHASH="$(awk -F= '/^artifact app-cdhash=/{print $2; exit}' "$SIGNING_TRACE_PATH")"
TRACE_EXTENSION_CDHASH="$(awk -F= '/^artifact extension-cdhash=/{print $2; exit}' "$SIGNING_TRACE_PATH")"
CURRENT_APP_CDHASH="$(awk -F= '/^CDHash=/{print $2; exit}' <<<"$SIGNING_SUMMARY")"
CURRENT_EXTENSION_CDHASH="$(awk -F= '/^CDHash=/{print $2; exit}' <<<"$EXTENSION_SIGNING_SUMMARY")"
[[ -n "$TRACE_APP_CDHASH" && "$TRACE_APP_CDHASH" == "$CURRENT_APP_CDHASH" ]] || fail "signing trace does not match current app"
[[ -n "$TRACE_EXTENSION_CDHASH" && "$TRACE_EXTENSION_CDHASH" == "$CURRENT_EXTENSION_CDHASH" ]] || fail "signing trace does not match current extension"
echo "$SIGNING_SUMMARY" >&2
echo "$EXTENSION_SIGNING_SUMMARY" >&2

if grep -qi "Signature=adhoc" <<<"$SIGNING_SUMMARY"; then
  echo "verify_app_bundle: ad-hoc signature detected." >&2
  echo "TCC caveat: ad-hoc re-signing can require re-adding Accessibility and Screen Recording permissions." >&2
fi

echo "verify_app_bundle: OK $APP_PATH" >&2
