// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Whispr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Whispr", targets: ["Whispr"])
    ],
    targets: [
        .executableTarget(
            name: "Whispr",
            path: "Whispr",
            exclude: [
                "Info.plist",
                "Whispr.entitlements",
                "Views/LiquidImplementation.md",
            ],
            resources: [
                .process("Assets.xcassets")
                //.copy("Views/LiquidImplementation.md") // Markdown doesn't need to be copied unless needed at runtime
            ]
        )
    ]
)
