// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexResetBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexResetBar", targets: ["CodexResetBar"]),
    ],
    targets: [
        .executableTarget(
            name: "CodexResetBar",
            path: "Sources/CodexResetBar",
            resources: [
                .process("Resources"),
            ]),
        .testTarget(
            name: "CodexResetBarTests",
            dependencies: ["CodexResetBar"],
            path: "Tests/CodexResetBarTests"),
    ])
