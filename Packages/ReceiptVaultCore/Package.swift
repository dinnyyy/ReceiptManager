// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ReceiptVaultCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ReceiptVaultCore", targets: ["ReceiptVaultCore"])
    ],
    targets: [
        .target(
            name: "ReceiptVaultCore",
            path: "Sources/ReceiptVaultCore"
        ),
        .testTarget(
            name: "ReceiptVaultCoreTests",
            dependencies: ["ReceiptVaultCore"],
            path: "Tests/ReceiptVaultCoreTests"
        ),
    ]
)
