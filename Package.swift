// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "APIErrorMiddleware",
    products: [
        .library(name: "APIErrorMiddleware", targets: ["APIErrorMiddleware"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0-rc")
    ],
    targets: [
        .target(name: "APIErrorMiddleware", dependencies: ["Vapor"]),
        .testTarget(name: "APIErrorMiddlewareTests", dependencies: ["APIErrorMiddleware"]),
    ]
)
