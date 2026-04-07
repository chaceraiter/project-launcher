// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ProjectLauncher",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "ProjectLauncher",
            targets: ["ProjectLauncher"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "ProjectLauncher",
            path: "Sources"
        ),
    ]
)
