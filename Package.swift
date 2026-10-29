// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pangolin",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Pangolin",
            path: "Sources/Pangolin",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)
