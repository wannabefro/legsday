// swift-tools-version: 6.0
import PackageDescription

// LegdaySim is the deterministic simulation core (KTD-1). It imports no
// SpriteKit/UIKit and supports macOS so `swift test` runs on the host with no
// simulator in the loop.
let package = Package(
    name: "LegdaySim",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LegdaySim", targets: ["LegdaySim"]),
    ],
    targets: [
        .target(name: "LegdaySim"),
        .testTarget(name: "LegdaySimTests", dependencies: ["LegdaySim"]),
    ]
)
