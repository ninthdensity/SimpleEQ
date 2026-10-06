// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleEQ",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SimpleEQ", targets: ["SimpleEQ"])],
    targets: [
        .executableTarget(name: "SimpleEQ")
    ]
)
