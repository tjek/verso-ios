// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Verso",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v9),
    ],
    products: [
        .library(
            name: "Verso",
            targets: ["Verso"]
        ),
    ],
    targets: [
        .target(name: "Verso")
    ]
)
