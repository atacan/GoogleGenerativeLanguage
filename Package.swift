// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GoogleGenerativeLanguage",
    platforms: [
        .iOS("16.0"),
        .macOS("13.0"),
        .watchOS("9.0"),
        .tvOS("16.0"),
        .visionOS("1.0"),
    ],
    products: [
        .library(
            name: "GoogleGenerativeLanguage",
            targets: ["GoogleGenerativeLanguage"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.7.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.8.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "GoogleGenerativeLanguage",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
            ]
        ),
        .executableTarget(name: "Prepare"),
        .testTarget(
            name: "GoogleGenerativeLanguageTests",
            dependencies: ["GoogleGenerativeLanguage", .product(name: "CustomDump", package: "swift-custom-dump")]
        ),
    ]
)
