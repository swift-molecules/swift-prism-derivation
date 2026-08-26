// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-prism-derivation",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Prism Derivation", targets: ["Prism Derivation"]),
        .library(name: "Prism Derivation Core", targets: ["Prism Derivation Core"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-primitives/swift-optic-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            "602.0.0"..<"603.0.0"
        ),
    ],
    targets: [
        .target(
            name: "Prism Derivation Core",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .macro(
            name: "Prism Derivation Macros",
            dependencies: [
                "Prism Derivation Core",
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Prism Derivation",
            dependencies: [
                "Prism Derivation Macros",
                .product(name: "Optic Primitives", package: "swift-optic-primitives"),
            ]
        ),
        .testTarget(
            name: "Prism Derivation Tests",
            dependencies: [
                "Prism Derivation",
                .product(name: "Optic Primitives", package: "swift-optic-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]
}
