// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MorseRadio",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MorseRadio", targets: ["MorseRadio"])
    ],
    targets: [
        .executableTarget(name: "MorseRadio")
    ]
)
