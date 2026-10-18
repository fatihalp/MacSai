// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacClean",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacClean", targets: ["MacClean"]),
        .executable(name: "MacCleanMenu", targets: ["MacCleanMenu"]),
        .library(name: "MacCleanKit", targets: ["MacCleanKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacClean",
            dependencies: [
                "MacCleanKit",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/MacClean"
        ),
        .executableTarget(
            name: "MacCleanMenu",
            dependencies: ["MacCleanKit"],
            path: "Sources/MacCleanMenu"
        ),
        .target(
            name: "MacCleanKit",
            dependencies: [],
            path: "Sources/MacCleanKit",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
