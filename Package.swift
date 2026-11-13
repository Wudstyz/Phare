// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Phare",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Phare", path: "Sources/Phare")
    ],
    swiftLanguageModes: [.v5]
)
