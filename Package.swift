// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexBarResetBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexBarResetBar", targets: ["CodexBarResetBar"]),
    ],
    targets: [
        .executableTarget(
            name: "CodexBarResetBar",
            path: "Sources/CodexBarResetBar",
            resources: [
                .process("Resources"),
            ]),
        .testTarget(
            name: "CodexBarResetBarTests",
            dependencies: ["CodexBarResetBar"],
            path: "Tests/CodexBarResetBarTests"),
    ])
