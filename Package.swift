// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeFlowmaxxing",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeFlowmaxxing",
            path: "Sources/ClaudeFlowmaxxing"
        )
    ]
)
