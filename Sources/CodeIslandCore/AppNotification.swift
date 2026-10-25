import Foundation

/// A notification captured from system notification center (e.g. WhatsApp Desktop).
public struct AppNotification: Identifiable, Equatable, Sendable {
    /// Unique identifier for this notification instance (UUID string).
    public let id: String
    /// Database record ID in Notification Center SQLite database.
    public let recordId: Int64
    /// Originating application's bundle identifier.
    public let bundleId: String
    /// Friendly application name (e.g. "WhatsApp").
    public let appName: String
    /// Sender or group chat title.
    public let sender: String
    /// Subtitle if present.
    public let subtitle: String?
    /// Message body content.
    public let body: String
    /// Delivery timestamp.
    public let date: Date

    public init(
        id: String,
        recordId: Int64,
        bundleId: String,
        appName: String,
        sender: String,
        subtitle: String? = nil,
        body: String,
        date: Date
    ) {
        self.id = id
        self.recordId = recordId
        self.bundleId = bundleId
        self.appName = appName
        self.sender = sender
        self.subtitle = subtitle
        self.body = body
        self.date = date
    }
}

