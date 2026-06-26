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
        .executableTarget(
            name: "DockHoverPreviewProbe",
            path: "Sources/DockHoverPreviewProbe",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit")
            ]
        ),
        .testTarget(
            name: "DockHoverPreviewProbeTests",
            dependencies: ["DockHoverPreviewProbe"],
            path: "Tests/DockHoverPreviewProbeTests"
        )
    ]
)
