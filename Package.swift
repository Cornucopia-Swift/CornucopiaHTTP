// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CornucopiaHTTP",
    platforms: [
        .macOS("12"),
        .iOS("15"),
        .tvOS("15"),
        .watchOS("8"),
        //.linux
    ],
    products: [
        .library(
            name: "CornucopiaHTTP",
            targets: ["CornucopiaHTTP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Cornucopia-Swift/CornucopiaCore", branch: "master"),
        .package(url: "https://github.com/tsolomko/SWCompression", from: "4.6.0"),
        .package(url: "https://github.com/mickeyl/FoundationBandAid", branch: "master"),
    ],
    targets: [
        .target(
            name: "CornucopiaHTTP",
            dependencies: [
                "CornucopiaCore",
                "SWCompression",
                  .product(name: "FoundationBandAid", package: "FoundationBandAid", condition: .when(platforms: [.linux])),
            ]
        ),
        .testTarget(
            name: "CornucopiaHTTPTests",
            dependencies: [
                "CornucopiaHTTP",
            ]
         ),
    ]
)
