// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LinkCompass",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LinkCompassCore", targets: ["LinkCompassCore"]),
        .executable(name: "LinkCompass", targets: ["LinkCompass"]),
        .executable(name: "linkcompass-eval", targets: ["LinkCompassEval"]),
        .executable(name: "linkcompass-native-host", targets: ["LinkCompassNativeHost"])
    ],
    targets: [
        .target(name: "LinkCompassCore"),
        .executableTarget(
            name: "LinkCompass",
            dependencies: ["LinkCompassCore"],
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "LinkCompassEval",
            dependencies: ["LinkCompassCore"]
        ),
        .executableTarget(
            name: "LinkCompassNativeHost",
            dependencies: ["LinkCompassCore"]
        ),
        .testTarget(
            name: "LinkCompassCoreTests",
            dependencies: ["LinkCompassCore"]
        )
    ]
)
