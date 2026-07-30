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

1. `Bundle.localizedInfoDictionary["CFBundleDisplayName"]`
2. `Bundle.localizedInfoDictionary["CFBundleName"]`
3. `Bundle.infoDictionary["CFBundleDisplayName"]`
4. `Bundle.infoDictionary["CFBundleName"]`
5. The `.app` bundle file name without its extension

The same order is already used when the user chooses an application with the
manual Add control. The implementation will consolidate that ordering into one
internal helper so the two entry points cannot diverge.

If the application cannot be found, or every candidate is absent or blank, the
resolver returns `nil`. The existing settings view then presents the bundle
identifier, retaining an understandable entry for a rule whose app is no longer
installed.

## Error Handling

No new error surface or persistence is required. Missing bundles and malformed
or empty name values use the existing fallback behavior. All system interaction
uses public AppKit and Foundation APIs.

## Tests

Add a focused XCTest that builds a temporary application bundle with both an
unlocalized display name and a localized `InfoPlist.strings` display name. It
must verify that the shared resolver chooses the localized value. Existing tests
continue to cover the normal unlocalized display-name path and the filename
fallback.

## Non-Goals

- Do not add per-application hard-coded name mappings.
- Do not persist display names in settings.
- Do not change the exclusion-rule storage schema or the settings layout.
