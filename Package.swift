// swift-tools-version:4.0
import PackageDescription
let package = Package(
    name: "APIErrorMiddleware",
    products: [
        .library(name: "APIErrorMiddleware", targets: ["APIErrorMiddleware"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "APIErrorMiddleware", dependencies: []),
        .testTarget(name: "APIErrorMiddlewareTests", dependencies: ["APIErrorMiddleware"]),
    ]
)