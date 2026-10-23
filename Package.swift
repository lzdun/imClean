// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "imClean",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "imClean", path: "Sources/imClean")
    ]
)
