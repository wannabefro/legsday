import Foundation
import Testing
@testable import Legday
import LegdaySim

/// The touch→Input translation glue (coalescing and phase collapse). The sim's
/// routing of that Input is covered by the package's InputRoutingTests.
struct TouchInputTests {
    @Test func heldTouchPersistsAsMovedAfterConsuming() {
        var acc = TouchInputAccumulator()
        acc.down(Vec2(100, 100))
        #expect(acc.current.phase == .began)
        acc.advance()                       // began consumed → now holding
        #expect(acc.current.phase == .moved)
        #expect(acc.current.location == Vec2(100, 100))
        acc.advance()                       // still held, no new event
        #expect(acc.current.phase == .moved)
    }

    @Test func sameFrameBeganThenMoveKeepsBegan() {
        var acc = TouchInputAccumulator()
        acc.down(Vec2(100, 100))
        acc.move(Vec2(140, 120))            // before the tick consumes .began
        #expect(acc.current.phase == .began) // began preserved so the sim anchors
        #expect(acc.current.location == Vec2(140, 120))
    }

    @Test func upBecomesEndedThenIdle() {
        var acc = TouchInputAccumulator()
        acc.down(Vec2(0, 0)); acc.advance()
        acc.move(Vec2(10, 0))
        acc.up(Vec2(20, 0))
        #expect(acc.current.phase == .ended)
        acc.advance()
        #expect(acc.current.phase == .idle)
    }

    @Test func cancelBecomesCancelledThenIdle() {
        var acc = TouchInputAccumulator()
        acc.down(Vec2(0, 0)); acc.advance()
        acc.cancel(Vec2(5, 5))
        #expect(acc.current.phase == .cancelled)
        acc.advance()
        #expect(acc.current.phase == .idle)
    }

    @Test func secondTouchIsIgnoredWhileOwned() {
        var acc = TouchInputAccumulator()
        acc.down(Vec2(100, 100))
        acc.advance()
        acc.down(Vec2(300, 300))            // a second finger — ignored
        #expect(acc.current.location == Vec2(100, 100))
        #expect(acc.hasOwner)
    }

    @Test func moveWithoutOwnerIsIgnored() {
        var acc = TouchInputAccumulator()
        acc.move(Vec2(50, 50))              // no touch owns the run
        #expect(acc.current.phase == .idle)
        #expect(!acc.hasOwner)
    }
}
