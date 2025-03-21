// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "FloatingChat",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "FloatingChat", targets: ["FloatingChat"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "FloatingChat",
            dependencies: ["KeyboardShortcuts"]
        )
    ]
) 