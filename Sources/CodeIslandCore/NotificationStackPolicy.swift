import Foundation

public enum NotificationStackPolicy {
    /// Threshold at which notifications are collapsed into a stack.
    /// 1 item shows as an individual row; 2 or more show as a stacked card.
    public static let stackThreshold = 2

    /// Maximum in-memory notifications kept in store.
    public static let maxItems = 50

    /// Maximum body characters retained in memory per notification.
    public static let maxBodyLength = 500

    /// Duration in seconds for notch peek overlay.
    public static let peekDuration: TimeInterval = 1.0

    /// Whether a count of notifications should be rendered stacked.
    public static func isStacked(count: Int) -> Bool {
        count >= stackThreshold
    }

    /// Truncate message body to stay within memory and display limits.
    public static func sanitizeBody(_ body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxBodyLength {
            return trimmed
        }
        return String(trimmed.prefix(maxBodyLength)) + "…"
    }

    /// Summary text formatted for the 1-second notch peek banner.
    public static func peekText(for arrivals: [AppNotification]) -> String {
        guard let first = arrivals.first else { return "" }
        if arrivals.count == 1 {
            let body = sanitizeBody(first.body)
            if first.sender.isEmpty {
                return body
            }
            if body.isEmpty {
                return first.sender
            }
            return "\(first.sender): \(body)"
        }
        return "\(arrivals.count) new messages"
    }
}

