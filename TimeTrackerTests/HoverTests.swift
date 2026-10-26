import CoreGraphics
import Foundation
import Testing
@testable import TimeTracker

@MainActor
struct HoverTests {
    func block(_ name: String) -> AppSessionBlockModel {
        AppSessionBlockModel(bundleIdentifier: name, appName: name, start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 120))
    }

    @Test func leavingAnotherBlockKeepsTheCurrentCard() {
        let state = TimelineHoverState()
        let a = HoverTarget.session(block("a")), b = HoverTarget.session(block("b"))
        state.enter(a, frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        state.enter(b, frame: CGRect(x: 0, y: 20, width: 10, height: 10))
        state.leave(a)                       // late "exit" event of the previous block
        #expect(state.hovered?.id == b.id)
        state.leave(b)
        #expect(state.hovered == nil)
    }

    @Test func updateOnlyAffectsTheHoveredBlock() {
        let state = TimelineHoverState()
        let a = HoverTarget.session(block("a")), b = HoverTarget.session(block("b"))
        state.update(a, frame: CGRect(x: 1, y: 1, width: 1, height: 1))
        #expect(state.hovered == nil)
        state.enter(a, frame: .zero)
        state.update(b, frame: CGRect(x: 5, y: 5, width: 5, height: 5))
        #expect(state.frame == .zero)
        state.update(a, frame: CGRect(x: 5, y: 5, width: 5, height: 5))
        #expect(state.frame.minY == 5)
    }

    let card = CGSize(width: 220, height: 100)
    func origin(_ block: CGRect, left: Bool, top: CGFloat = 0, bottom: CGFloat = 600) -> CGPoint {
        HoverCardPlacement.origin(for: block, opensToLeft: left, cardSize: card, columnWidth: 600, columnHeight: 2000,
                                  minX: 54, visibleTop: top, visibleBottom: bottom)
    }

    @Test func sessionCardOpensRightOfTheBlockAlignedToItsTop() {
        let p = origin(CGRect(x: 60, y: 300, width: 200, height: 20), left: false)
        #expect(p == CGPoint(x: 268, y: 300))
    }

    @Test func entryCardOpensLeftAndStaysInsideTheColumn() {
        #expect(origin(CGRect(x: 300, y: 300, width: 250, height: 20), left: true).x == 72)
        #expect(origin(CGRect(x: 100, y: 300, width: 250, height: 20), left: true).x == 54)
        #expect(origin(CGRect(x: 60, y: 300, width: 500, height: 20), left: false).x == 376)
    }

    @Test func cardIsKeptInsideTheVisibleArea() {
        #expect(origin(CGRect(x: 60, y: 580, width: 100, height: 20), left: false, top: 0, bottom: 600).y == 496)
        #expect(origin(CGRect(x: 60, y: 100, width: 100, height: 3000), left: false, top: 1000, bottom: 1600).y == 1004)
        #expect(origin(CGRect(x: 60, y: 1990, width: 100, height: 5), left: false, top: 1500, bottom: 2100).y == 1900)
    }
}
