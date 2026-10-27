// swift-tools-version: 6.0
import PackageDescription

// A host-only test target for data parsing and time math. The iOS app lives in Krill.xcodeproj.
let package = Package(
    name: "KrillCoreChecks",
    platforms: [.macOS(.v14)],
    products: [.library(name: "Krill", targets: ["Krill"])],
    targets: [
        .target(name: "Krill", path: "Krill",
                exclude: ["KrillApp.swift", "Features", "Design", "Resources"],
                sources: ["Models", "Services"]),
        .testTarget(name: "KrillCoreTests", dependencies: ["Krill"], path: "KrillTests")
    ],
    swiftLanguageModes: [.v5]
)
