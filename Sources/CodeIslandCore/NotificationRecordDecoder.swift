import Foundation

public enum NotificationRecordDecoder {
    /// Supported WhatsApp bundle identifiers.
    public static let supportedBundleIds: Set<String> = [
        "net.whatsapp.WhatsApp",
        "desktop.WhatsApp",
        "net.whatsapp.WhatsApp.desktop",
    ]

    /// Parse SQLite delivered_date timestamp into Foundation Date.
    public static func parseDate(_ raw: Double) -> Date {
        if raw <= 0 {
            return Date()
        }
        if raw > 10_000_000_000 {
            // Milliseconds since 1970
            return Date(timeIntervalSince1970: raw / 1000.0)
        }
        if raw > 1_000_000_000 {
            // Seconds since 1970
            return Date(timeIntervalSince1970: raw)
        }
        // CoreFoundation date: seconds since Jan 1 2001
        return Date(timeIntervalSinceReferenceDate: raw)
    }

    /// Convert 16-byte raw BLOB to UUID string.
    public static func parseUUID(from data: Data?) -> String? {
        guard let data, data.count == 16 else { return nil }
        return data.withUnsafeBytes { ptr -> String in
            let uuid = ptr.load(as: uuid_t.self)
            return UUID(uuid: uuid).uuidString
        }
    }

    /// Friendly display name for a bundle identifier.
    public static func friendlyAppName(for bundleId: String) -> String {
        let lower = bundleId.lowercased()
        if lower.contains("whatsapp") {
            return "WhatsApp"
        }
        if let last = bundleId.split(separator: ".").last, !last.isEmpty {
            return String(last)
        }
        return bundleId
    }

    /// Decode raw notification record payload into `AppNotification`.
    public static func decode(
        recordId: Int64,
        uuidBytes: Data?,
        dataBlob: Data,
        bundleId: String,
        deliveredDateRaw: Double
    ) -> AppNotification? {
        guard let plist = try? PropertyListSerialization.propertyList(
            from: dataBlob,
            options: [],
            format: nil
        ) as? [String: Any] else {
            return nil
        }

        let req = plist["req"] as? [String: Any]

        let title = (req?["titl"] as? String)
            ?? (plist["titl"] as? String)
            ?? (plist["title"] as? String)
            ?? ""

        let subtitle = (req?["subt"] as? String)
            ?? (plist["subt"] as? String)
            ?? (plist["subtitle"] as? String)

        let body = (req?["body"] as? String)
            ?? (plist["body"] as? String)
            ?? (req?["message"] as? String)
            ?? (plist["message"] as? String)
            ?? ""

        let date = parseDate(deliveredDateRaw)

        let id = parseUUID(from: uuidBytes)
            ?? (req?["uuid"] as? String)
            ?? (plist["uuid"] as? String)
            ?? UUID().uuidString

        let appName = friendlyAppName(for: bundleId)

        let sender = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title.trimmingCharacters(in: .whitespacesAndNewlines)
            : (subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? subtitle! : appName)

        return AppNotification(
            id: id,
            recordId: recordId,
            bundleId: bundleId,
            appName: appName,
            sender: sender,
            subtitle: subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
            body: NotificationStackPolicy.sanitizeBody(body),
            date: date
        )
    }
}

