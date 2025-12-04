// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VolcanoGame",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VolcanoGame", targets: ["VolcanoGame"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VolcanoGame",
            dependencies: [],
            resources: []
        )
    ]
)