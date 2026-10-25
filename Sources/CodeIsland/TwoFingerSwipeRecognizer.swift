import AppKit
import Foundation

public enum SwipeDirection: Equatable, Sendable {
    case next
    case previous
}

public enum SwipeAction: Equatable, Sendable {
    case passThrough
    case tracking(offset: CGFloat)
    case commit(SwipeDirection)
    case cancel
}

/// Pure state machine for recognizing horizontal two-finger trackpad swipes.
public struct TwoFingerSwipeStateMachine {
    private enum AxisLock {
        case undecided
        case horizontal
        case vertical
    }

    private var axis: AxisLock = .undecided
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0

    /// Minimum threshold to lock to horizontal axis.
    public static let lockThreshold: CGFloat = 12
    /// Minimum threshold to commit a tab switch on finger release.
    public static let commitThreshold: CGFloat = 45

    public init() {}

    public mutating func reset() {
        axis = .undecided
        accumulatedX = 0
        accumulatedY = 0
    }

    public mutating func process(
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        deltaX: CGFloat,
        deltaY: CGFloat,
        isInverted: Bool
    ) -> SwipeAction {
        // Discard momentum events completely to prevent jumping multiple tabs after flick
        if !momentumPhase.isEmpty {
            return .passThrough
        }

        if phase.contains(.began) {
            reset()
            return .passThrough
        }

        if phase.contains(.changed) {
            accumulatedX += deltaX
            accumulatedY += deltaY

            if axis == .undecided {
                if abs(accumulatedX) > Self.lockThreshold && abs(accumulatedX) > 1.3 * abs(accumulatedY) {
                    axis = .horizontal
                } else if abs(accumulatedY) > Self.lockThreshold {
                    axis = .vertical
                }
            }

            if axis == .horizontal {
                let trackingOffset = (isInverted ? accumulatedX : -accumulatedX) * 0.4
                return .tracking(offset: trackingOffset)
            } else {
                return .passThrough
            }
        }

        if phase.contains(.ended) {
            defer { reset() }
            if axis == .horizontal {
                let effectiveMotion = isInverted ? accumulatedX : -accumulatedX
                if abs(effectiveMotion) >= Self.commitThreshold {
                    return .commit(effectiveMotion > 0 ? .previous : .next)
                } else {
                    return .cancel
                }
            }
            return .passThrough
        }

        if phase.contains(.cancelled) {
            reset()
            return .cancel
        }

        return .passThrough
    }
}

/// Local monitor for trackpad two-finger scroll wheel events.
@MainActor
public final class TwoFingerSwipeMonitor {
    private var monitor: Any?
    private var stateMachine = TwoFingerSwipeStateMachine()

    public init() {}

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    public func start(
        onTracking: @escaping (CGFloat) -> Void,
        onCommit: @escaping (SwipeDirection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }

            // Only trackpad provides precise scrolling deltas
            guard event.hasPreciseScrollingDeltas else { return event }

            let action = self.stateMachine.process(
                phase: event.phase,
                momentumPhase: event.momentumPhase,
                deltaX: event.scrollingDeltaX,
                deltaY: event.scrollingDeltaY,
                isInverted: event.isDirectionInvertedFromDevice
            )

            switch action {
            case .tracking(let offset):
                onTracking(offset)
                return nil // Consume event
            case .commit(let direction):
                onCommit(direction)
                return nil
            case .cancel:
                onCancel()
                return nil
            case .passThrough:
                return event
            }
        }
    }

    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        stateMachine.reset()
    }
}
