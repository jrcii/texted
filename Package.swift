// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TextEd",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "CSimd"),
        .executableTarget(name: "TextEd", dependencies: ["CSimd"]),
    ]
)
