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
        .visionOS("1.0")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GoogleGenerativeLanguage",
            targets: ["GoogleGenerativeLanguage"]),
        .library(
            name: "GoogleGenerativeLanguage_AHC",
            targets: [ "GoogleGenerativeLanguage_AHC" ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GoogleGenerativeLanguage"),
        .testTarget(
            name: "GoogleGenerativeLanguageTests",
            dependencies: ["GoogleGenerativeLanguage"]
        ),
        .target(name: "GoogleGenerativeLanguage_AHC",dependencies: [
    .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
    .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),]),
        .executableTarget(name: "Prepare"),
        .testTarget(
            name: "GoogleGenerativeLanguage_AHCTests",
            dependencies: [ "GoogleGenerativeLanguage_AHC" ]
        ),
    ]
)
