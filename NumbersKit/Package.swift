// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NumbersKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "NumbersKit", targets: ["NumbersKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0")
    ],
    targets: [
        .target(
            name: "NumbersKit",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            exclude: ["Proto/NOTICE.md"]
        ),
        .testTarget(
            name: "NumbersKitTests",
            dependencies: ["NumbersKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
