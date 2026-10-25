import XCTest
@testable import CodeIsland

final class TwoFingerSwipeTests: XCTestCase {
    func testIgnoresMomentumPhase() {
        var sm = TwoFingerSwipeStateMachine()
        let action = sm.process(
            phase: .changed,
            momentumPhase: .began,
            deltaX: 50,
            deltaY: 0,
            isInverted: false
        )
        XCTAssertEqual(action, .passThrough)
    }

    func testLocksToVerticalWhenScrollPredominantlyVertical() {
        var sm = TwoFingerSwipeStateMachine()
        _ = sm.process(phase: .began, momentumPhase: [], deltaX: 0, deltaY: 0, isInverted: false)
        let changed = sm.process(phase: .changed, momentumPhase: [], deltaX: 2, deltaY: 20, isInverted: false)
        XCTAssertEqual(changed, .passThrough)

        let ended = sm.process(phase: .ended, momentumPhase: [], deltaX: 0, deltaY: 0, isInverted: false)
        XCTAssertEqual(ended, .passThrough)
    }

    func testLocksToHorizontalAndCommitsNext() {
        var sm = TwoFingerSwipeStateMachine()
        _ = sm.process(phase: .began, momentumPhase: [], deltaX: 0, deltaY: 0, isInverted: false)
        let changed = sm.process(phase: .changed, momentumPhase: [], deltaX: -30, deltaY: 1, isInverted: false)
        if case .tracking(let offset) = changed {
            XCTAssertEqual(offset, -30 * 0.4)
        } else {
            XCTFail("Expected tracking action")
        }

        let changedMore = sm.process(phase: .changed, momentumPhase: [], deltaX: -30, deltaY: 0, isInverted: false)
        if case .tracking(let offset) = changedMore {
            XCTAssertEqual(offset, -60 * 0.4)
        } else {
            XCTFail("Expected tracking action")
        }

        let ended = sm.process(phase: .ended, momentumPhase: [], deltaX: 0, deltaY: 0, isInverted: false)
        XCTAssertEqual(ended, .commit(.next))
    }

    func testUnderThresholdCancels() {
        var sm = TwoFingerSwipeStateMachine()
        _ = sm.process(phase: .began, momentumPhase: [], deltaX: 0, deltaY: 0, isInverted: false)
        _ = sm.process(phase: .changed, momentumPhase: [], deltaX: 20, deltaY: 0, isInverted: false)
        let ended = sm.process(phase: .ended, momentumPhase: [], deltaX: 0, deltaY: 0, isInverted: false)
        XCTAssertEqual(ended, .cancel)
    }
}

