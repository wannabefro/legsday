import XCTest
@testable import LegdaySim

/// The cross-platform strategy, made executable.
///
/// `LegdaySim` holds every rule of the game and imports only Foundation, so it
/// compiles anywhere Swift does. Porting the game to Android, Windows or the
/// web means rewriting the render layer and nothing else. One `import SpriteKit`
/// in this target silently ends that, and the app would still build, so the
/// invariant needs a test rather than a convention.
final class PortabilityTests: XCTestCase {

    /// Foundation only. Nothing Apple-only, nothing platform-bound.
    private static let allowed: Set<String> = ["Foundation"]

    func testSimImportsOnlyPortableModules() throws {
        var offenders: [String] = []

        for url in try Self.simSourceFiles() {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let module = trimmed
                    .dropFirst("import ".count)
                    .trimmingCharacters(in: .whitespaces)
                    .split(separator: ".").first.map(String.init) ?? ""
                if !Self.allowed.contains(module) {
                    offenders.append("\(url.lastPathComponent):\(n + 1) imports \(module)")
                }
            }
        }

        XCTAssertEqual(
            offenders, [],
            """
            LegdaySim must import Foundation only. It is the portable half of \
            the codebase and the reason a port costs a render layer instead of \
            a rewrite. Move the offending code into the app target.
            """
        )
    }

    /// The sim must also be free of the render layer's vocabulary, which is how
    /// platform types usually arrive: as a `CGPoint` in a signature.
    func testSimUsesNoGraphicsTypes() throws {
        let banned = ["CGPoint", "CGFloat", "CGRect", "CGSize", "SKNode", "UIColor", "UIView"]
        var offenders: [String] = []

        for url in try Self.simSourceFiles() {
            let text = try String(contentsOf: url, encoding: .utf8)
            for name in banned where text.contains(name) {
                offenders.append("\(url.lastPathComponent) mentions \(name)")
            }
        }

        XCTAssertEqual(offenders, [], "The sim speaks in Vec2 and Double, never in platform types.")
    }

    private static func simSourceFiles() throws -> [URL] {
        // Tests/LegdaySimTests/<this file> -> Sources/LegdaySim
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // LegdaySimTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // LegdaySim (package root)
            .appendingPathComponent("Sources/LegdaySim")

        let found = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        // A path that silently resolves to nothing would make this test pass
        // while checking no files at all.
        XCTAssertGreaterThan(found.count, 10, "Found no sim sources at \(sources.path)")
        return found
    }
}
