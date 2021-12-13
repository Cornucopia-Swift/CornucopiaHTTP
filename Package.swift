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
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CornucopiaHTTP",
            targets: ["CornucopiaHTTP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Cornucopia-Swift/CornucopiaCore", branch: "master"),
        .package(url: "https://github.com/tsolomko/SWCompression", from: "4.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CornucopiaHTTP",
            dependencies: [
                "CornucopiaCore",
                "SWCompression",
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
