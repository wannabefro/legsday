// swift-tools-version: 6.0
import PackageDescription

// The web build. `LegdaySim` is the game; this package is only the C ABI a
// browser calls across. Kept out of the app's package so Xcode never sees it.
let package = Package(
    name: "LegdayWasm",
    dependencies: [.package(path: "../Packages/LegdaySim")],
    targets: [
        .executableTarget(
            name: "LegdayWasm",
            dependencies: [.product(name: "LegdaySim", package: "LegdaySim")],
            swiftSettings: [.unsafeFlags(["-Osize"])],
            // `@_cdecl` names the symbol; wasm still needs each one exported.
            linkerSettings: [.unsafeFlags(
                // `RunState` is a large struct; the wasm default stack is not
                // enough to build one and the run trapped out of bounds.
                ["-Xclang-linker", "-mexec-model=reactor",
                 "-Xlinker", "-z", "-Xlinker", "stack-size=4194304"]
                + ["legday_boot", "legday_inbox", "legday_start", "legday_tick",
                   "legday_frame", "legday_text"].flatMap { ["-Xlinker", "--export=\($0)"] }
            )]
        )
    ]
)
