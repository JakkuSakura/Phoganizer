// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SakuraPhoto",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "SakuraPhoto", path: "Sources/SakuraPhoto")]
)
