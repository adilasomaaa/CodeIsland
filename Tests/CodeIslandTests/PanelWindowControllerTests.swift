import AppKit
import XCTest
@testable import CodeIsland

final class PanelWindowControllerTests: XCTestCase {
    func testPanelPlacementAndFloatingGap() {
        let screen = NSRect(x: 1440, y: 0, width: 1440, height: 900)
        let visible = NSRect(x: 1440, y: 0, width: 1440, height: 863)
        let width: CGFloat = 620
        let height: CGFloat = 510

        XCTAssertEqual(PanelPositionMetrics.baseX(panelWidth: width, screenFrame: screen, placement: .left), 1456)
        XCTAssertEqual(PanelPositionMetrics.baseX(panelWidth: width, screenFrame: screen, placement: .center), 1850)
        XCTAssertEqual(PanelPositionMetrics.baseX(panelWidth: width, screenFrame: screen, placement: .right), 2244)
        XCTAssertEqual(PanelPositionMetrics.originY(panelHeight: height, screenFrame: screen, visibleFrame: visible, style: .attached), 390)
        XCTAssertEqual(PanelPositionMetrics.originY(panelHeight: height, screenFrame: screen, visibleFrame: visible, style: .floating), 341)
    }

    func testScreenHopMotionUsesMoreVisibleTiming() {
        let motion = PanelWindowController.screenHopMotion()

        XCTAssertEqual(motion.outgoingOffset, 18)
        XCTAssertEqual(motion.incomingOffset, 30)
        XCTAssertEqual(motion.fadeOutDuration, 0.14, accuracy: 0.001)
        XCTAssertEqual(motion.incomingPauseDuration, 0.06, accuracy: 0.001)
        XCTAssertEqual(motion.fadeInDuration, 0.34, accuracy: 0.001)
    }

    func testScreenHopFramesRetractOldFrameAndDropIntoNewFrame() {
        let oldFrame = NSRect(x: 100, y: 820, width: 420, height: 180)
        let newFrame = NSRect(x: 1800, y: 900, width: 420, height: 180)

        let frames = PanelWindowController.screenHopFrames(
            oldFrame: oldFrame,
            newFrame: newFrame
        )

        XCTAssertEqual(frames.outgoing.origin.x, oldFrame.origin.x)
        XCTAssertEqual(frames.outgoing.origin.y, oldFrame.origin.y + 18)
        XCTAssertEqual(frames.outgoing.size, oldFrame.size)

        XCTAssertEqual(frames.incoming.origin.x, newFrame.origin.x)
        XCTAssertEqual(frames.incoming.origin.y, newFrame.origin.y + 30)
        XCTAssertEqual(frames.incoming.size, newFrame.size)
    }
}
