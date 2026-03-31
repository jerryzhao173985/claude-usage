// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Claude2xNotifier",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Claude2xNotifier",
            path: "Sources/Claude2xNotifier"
        )
    ]
)
