// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XinReader",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .executableTarget(
            name: "XinReader",
            dependencies: ["ZIPFoundation"],
            path: "XinReader",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "XinReaderTests",
            dependencies: ["XinReader"],
            path: "XinReaderTests"
        )
    ]
)
