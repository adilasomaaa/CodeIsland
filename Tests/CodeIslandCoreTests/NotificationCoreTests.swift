import XCTest
@testable import CodeIslandCore

final class NotificationCoreTests: XCTestCase {
    func testNotificationStackPolicyThreshold() {
        XCTAssertFalse(NotificationStackPolicy.isStacked(count: 0))
        XCTAssertFalse(NotificationStackPolicy.isStacked(count: 1))
        XCTAssertTrue(NotificationStackPolicy.isStacked(count: 2))
        XCTAssertTrue(NotificationStackPolicy.isStacked(count: 5))
    }

    func testNotificationStackPolicySanitizeBody() {
        let short = "Hello world"
        XCTAssertEqual(NotificationStackPolicy.sanitizeBody(short), "Hello world")

        let long = String(repeating: "A", count: 600)
        let sanitized = NotificationStackPolicy.sanitizeBody(long)
        XCTAssertEqual(sanitized.count, 501) // 500 + "…"
        XCTAssertTrue(sanitized.hasSuffix("…"))
    }

    func testNotificationStackPolicyPeekText() {
        let notif1 = AppNotification(
            id: "uuid-1",
            recordId: 101,
            bundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            sender: "Alice",
            body: "Are you free tonight?",
            date: Date()
        )
        XCTAssertEqual(NotificationStackPolicy.peekText(for: [notif1]), "Alice: Are you free tonight?")

        let notif2 = AppNotification(
            id: "uuid-2",
            recordId: 102,
            bundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            sender: "Bob",
            body: "Meeting at 3",
            date: Date()
        )
        XCTAssertEqual(NotificationStackPolicy.peekText(for: [notif1, notif2]), "2 new messages")
    }

    func testNotificationRecordDecoderValidPlist() throws {
        let payload: [String: Any] = [
            "req": [
                "titl": "John Doe",
                "subt": "Work Group",
                "body": "Hey everyone, check this PR",
                "uuid": "custom-uuid-1234"
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)

        let notif = NotificationRecordDecoder.decode(
            recordId: 42,
            uuidBytes: nil,
            dataBlob: data,
            bundleId: "net.whatsapp.WhatsApp",
            deliveredDateRaw: 1700000000
        )

        XCTAssertNotNil(notif)
        XCTAssertEqual(notif?.recordId, 42)
        XCTAssertEqual(notif?.appName, "WhatsApp")
        XCTAssertEqual(notif?.sender, "John Doe")
        XCTAssertEqual(notif?.subtitle, "Work Group")
        XCTAssertEqual(notif?.body, "Hey everyone, check this PR")
        XCTAssertEqual(notif?.id, "custom-uuid-1234")
    }

    func testNotificationRecordDecoderFallbackToSubtitleWhenTitleEmpty() throws {
        let payload: [String: Any] = [
            "req": [
                "titl": "",
                "subt": "Family Chat",
                "body": "Dinner is ready"
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)

        let notif = NotificationRecordDecoder.decode(
            recordId: 43,
            uuidBytes: nil,
            dataBlob: data,
            bundleId: "desktop.WhatsApp",
            deliveredDateRaw: 1700000000
        )

        XCTAssertNotNil(notif)
        XCTAssertEqual(notif?.sender, "Family Chat")
        XCTAssertEqual(notif?.body, "Dinner is ready")
    }

    func testNotificationRecordDecoderUUIDBytes() throws {
        let payload: [String: Any] = [
            "req": [
                "titl": "Alice",
                "body": "Hi"
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)

        var rawUuid = UUID().uuid
        let uuidBytes = withUnsafeBytes(of: &rawUuid) { Data($0) }

        let notif = NotificationRecordDecoder.decode(
            recordId: 44,
            uuidBytes: uuidBytes,
            dataBlob: data,
            bundleId: "net.whatsapp.WhatsApp",
            deliveredDateRaw: 1700000000
        )

        XCTAssertNotNil(notif)
        XCTAssertEqual(notif?.id, UUID(uuid: rawUuid).uuidString)
    }
}

