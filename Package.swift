// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LilCleo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LilCleo",
            path: "Sources/LilCleo",
            resources: [
                // Copy (not process) preserves the characters/<name>/<state>.png
                // tree so per-character sprites with identical names don't collide.
                .copy("Resources/characters"),
                .process("Resources/README.md")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
