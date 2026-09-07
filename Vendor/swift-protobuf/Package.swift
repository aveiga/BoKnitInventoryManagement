// swift-tools-version:6.0

// Vendored copy of apple/swift-protobuf, library target only.
//
// Why vendored: the Xcode Cloud workflow wizard requires an access grant for
// every repository in the package graph, and that grant cannot be given for a
// repository you do not administer (apple/swift-protobuf). Keeping the sources
// local removes it from the remote graph entirely.
//
// Upstream version is recorded in VENDORED_VERSION.txt. To update, replace
// Sources/SwiftProtobuf with the new tag's Sources/SwiftProtobuf and bump that
// file. Nothing else here should need to change.
//
// Deviations from upstream Package.swift, all deliberate:
//   - Only the SwiftProtobuf library target is declared. The protoc /
//     protoc-gen-swift executables and the build-tool plugin are omitted; the
//     .pb.swift files in NumbersKit are already generated and checked in.
//   - Upstream gates BinaryDelimited and FieldMask behind SwiftPM traits, which
//     need tools-version 6.2. They are passed as plain defines here so the
//     compiled surface matches upstream's default-enabled traits.

import PackageDescription

#if canImport(Darwin)
let resources: [Resource] = [.copy("PrivacyInfo.xcprivacy")]
#else
let resources = [Resource]()
#endif

let package = Package(
    name: "SwiftProtobuf",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SwiftProtobuf", targets: ["SwiftProtobuf"])
    ],
    targets: [
        .target(
            name: "SwiftProtobuf",
            exclude: ["CMakeLists.txt"],
            resources: resources,
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .define("BinaryDelimitedStreams"),
                .define("FieldMaskUtilities"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
