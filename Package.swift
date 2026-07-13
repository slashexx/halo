// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Halo",
    platforms: [
        // macOS 26 (Tahoe) — required for the Liquid Glass SwiftUI APIs.
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "Halo",
            path: "Sources/Halo",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
