// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LinkCompass",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LinkCompassCore", targets: ["LinkCompassCore"]),
        .executable(name: "LinkCompass", targets: ["LinkCompass"])
    ],
    targets: [
        .target(name: "LinkCompassCore"),
        .executableTarget(
            name: "LinkCompass",
            dependencies: ["LinkCompassCore"],
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "LinkCompassCoreTests",
            dependencies: ["LinkCompassCore"]
        )
    ]
)
