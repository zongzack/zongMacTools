// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockHoverPreviewProbe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DockHoverPreviewProbe", targets: ["DockHoverPreviewProbe"])
    ],
    targets: [
        .target(
            name: "FinderNewFileCore",
            path: "Sources/FinderNewFileCore"
        ),
        .executableTarget(
            name: "DockHoverPreviewProbe",
            dependencies: ["FinderNewFileCore"],
            path: "Sources/DockHoverPreviewProbe",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("FinderSync")
            ]
        ),
        .executableTarget(
            name: "FinderSyncExtension",
            dependencies: ["FinderNewFileCore"],
            path: "Sources/FinderSyncExtension",
            exclude: ["Info.plist", "FinderSyncExtension.entitlements"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("FinderSync")
            ]
        ),
        .testTarget(
            name: "DockHoverPreviewProbeTests",
            dependencies: ["DockHoverPreviewProbe", "FinderNewFileCore"],
            path: "Tests/DockHoverPreviewProbeTests"
        )
    ]
)
