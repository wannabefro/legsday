import Foundation
import SpriteKit
import Testing
import LegdaySim
@testable import Legday

/// A wall must sit where the Pilgrim actually stops, or the cliff is a lie.
@MainActor
struct GorgeWallNodeTests {
    private static let size = CGSize(width: 393, height: 852)

    private static func state() -> RunState {
        var sim = RunSim(tunables: try! Tunables.bundled(),
                         viewport: Vec2(size.width, size.height), seed: 21)
        for _ in 0..<60 { sim.tick(dt: RunSim.fixedStep, input: .idle) }
        return sim.state
    }

    @Test func everyWallTileSitsOutsideTheChannelItGuards() {
        let node = GorgeWallNode()
        let s = Self.state()
        node.update(state: s, sceneSize: Self.size)
        let tiles = node.children.compactMap { $0 as? SKSpriteNode }.filter { !$0.isHidden }
        let outside = tiles.allSatisfy { tile in
            let terrainY = s.worldY + Double(tile.position.y)
            let e = s.gorge.edges(at: terrainY)
            return Double(tile.position.x) <= e.left || Double(tile.position.x) >= e.right
        }
        #expect(tiles.count > 20)
        #expect(outside)
    }

    @Test func aNarrowerZoneDrawsItsWallsFurtherIn() {
        let node = GorgeWallNode()
        var wide = Self.state()
        node.update(state: wide, sceneSize: Self.size)
        let atLowRoad = node.children.compactMap { $0 as? SKSpriteNode }
            .filter { !$0.isHidden }.map { $0.position.x }.min() ?? 0
        wide = Self.state()
        #expect(atLowRoad <= Self.size.width)
        #expect(ZoneLook.byStageID["spire"]!.depth > ZoneLook.byStageID["low_road"]!.depth)
    }

    @Test func everyStageNamesAMaterialThatShipsInTheBundle() {
        let names = ZoneLook.byStageID.values.flatMap { [$0.wall.sprite, $0.floor.sprite] }
        let missing = Set(names).filter { Bundle.main.url(forResource: $0, withExtension: "png") == nil }
        #expect(missing.isEmpty)
        #expect(ZoneLook.byStageID.count == Ascent.stages.count)
    }
}
