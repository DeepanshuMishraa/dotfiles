// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RiftBorders",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "rift-borders", targets: ["rift-borders"]),
    ],
    targets: [
        .target(name: "RiftBordersCore"),
        .executableTarget(
            name: "rift-borders",
            dependencies: ["RiftBordersCore"],
            linkerSettings: [
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "SkyLight"
                ])
            ]
        ),
        .testTarget(
            name: "RiftBordersCoreTests",
            dependencies: ["RiftBordersCore"]
        ),
    ]
)
