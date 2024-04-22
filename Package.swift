// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Postmark",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.1"),
        .package(path: "/Users/john/Projects/FileMonitor"),
        .package(url: "https://github.com/johnsundell/ink.git", from: "0.1.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(name: "Postmark", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SQLite", package: "SQLite.swift"),
            .product(name: "FileMonitor", package: "FileMonitor"),
            .product(name: "Ink", package: "ink"),
            .product(name: "SwiftSoup", package: "SwiftSoup")
        ]),
        .testTarget(name: "Postmark-Tests", dependencies: ["Postmark"], resources: [.copy("Example.md")])
    ]
)
