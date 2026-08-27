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
            path: "Sources/FinderNewFileCore",
            exclude: ["Resources/BlankWord", "Resources/BlankExcel", "Resources/BlankPowerPoint"],
            resources: [
                .copy("Resources/BlankWord.zip"),
                .copy("Resources/BlankExcel.zip"),
                .copy("Resources/BlankPowerPoint.zip")
            ]
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
                .linkedFramework("FinderSync"),
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])
            ]
        ),
        .testTarget(
            name: "DockHoverPreviewProbeTests",
            dependencies: ["DockHoverPreviewProbe", "FinderNewFileCore"],
            path: "Tests/DockHoverPreviewProbeTests"
        )
    ]
)
