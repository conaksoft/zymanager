// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ZyManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ZyManager",
            path: "Sources/ZyManager"
        )
    ]
)
