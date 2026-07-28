// swift-tools-version: 6.0
import PackageDescription

let rustLinkerSettings: [LinkerSetting] = [
    .unsafeFlags([
        "-Xlinker",
        "rust/target/release/libtokpeek_core_ffi.a",
    ]),
    .linkedFramework("Security"),
    .linkedFramework("SystemConfiguration"),
    .linkedFramework("CoreFoundation"),
    .linkedLibrary("c++"),
    .linkedLibrary("resolv"),
]

let package = Package(
    name: "TokPeek",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TokPeek", targets: ["TokPeek"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.4"
        ),
    ],
    targets: [
        .target(
            name: "TokPeekKit",
            path: "Sources/TokPeekKit"
        ),
        .target(
            name: "CTokPeekCore",
            path: "Sources/CTokPeekCore",
            publicHeadersPath: "include"
        ),
        .target(
            name: "TokPeekBridge",
            dependencies: ["CTokPeekCore", "TokPeekKit"],
            path: "Sources/TokPeekBridge"
        ),
        .executableTarget(
            name: "TokPeek",
            dependencies: [
                "TokPeekBridge",
                "TokPeekKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/TokPeek",
            linkerSettings: rustLinkerSettings
        ),
        .testTarget(
            name: "TokPeekKitTests",
            dependencies: ["TokPeekKit"],
            path: "Tests/TokPeekKitTests"
        ),
    ]
)
