# Localized Excluded App Names Design

## Purpose

The exclusion-rule list must show each application name as it appears in the
current macOS language. For example, the bundle `com.bot.neotix.doubao` should
show `豆包` when its installed application bundle provides that localized name,
instead of its unlocalized `Doubao` value.

## Scope

This change only affects the user-visible name resolved from a saved excluded
application bundle identifier. Exclusion rules remain stored, compared, sorted,
and removed by bundle identifier.

## Design

`WorkspaceAppNameResolver` will keep using the public
`NSWorkspace.urlForApplication(withBundleIdentifier:)` API to locate the
installed application. Once it has a bundle URL, it will resolve the first
non-empty name in this order:

1. The application bundle's Finder display name without its `.app` suffix
2. `Bundle.localizedInfoDictionary["CFBundleDisplayName"]`
3. `Bundle.localizedInfoDictionary["CFBundleName"]`
4. `Bundle.infoDictionary["CFBundleDisplayName"]`
5. `Bundle.infoDictionary["CFBundleName"]`
6. The `.app` bundle file name without its extension

The Finder display name is first because it is the name shown to the user in
Applications and does not depend on Foundation matching the system's language
tag to the app's available `.lproj` folders. The implementation consolidates
this ordering into one internal helper so the saved-rule and manual-Add entry
points cannot diverge.

If the application cannot be found, or every candidate is absent or blank, the
resolver returns `nil`. The existing settings view then presents the bundle
identifier, retaining an understandable entry for a rule whose app is no longer
installed.

## Error Handling

No new error surface or persistence is required. Missing bundles and malformed
or empty name values use the existing fallback behavior. All system interaction
uses public AppKit and Foundation APIs.

## Tests

Add focused XCTest coverage for a temporary application bundle with both an
unlocalized display name and a localized `InfoPlist.strings` display name, and
for an app bundle whose visible filename differs from its bundle metadata. The
tests must verify that the resolver chooses the name displayed in Applications
and retains filename fallback when metadata is missing.

## Non-Goals

- Do not add per-application hard-coded name mappings.
- Do not persist display names in settings.
- Do not change the exclusion-rule storage schema or the settings layout.
