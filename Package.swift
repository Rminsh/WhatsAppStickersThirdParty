// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhatsAppStickersThirdParty",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "WhatsAppStickersThirdParty",
            targets: ["WhatsAppStickersThirdParty"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImageWebPCoder.git", from: "0.8.4")
    ],
    targets: [
        .target(
            name: "WhatsAppStickersThirdParty",
            dependencies: ["SDWebImageWebPCoder"]
        ),
    ]
)
