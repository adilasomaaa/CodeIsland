import XCTest
@testable import CodeIsland
import CodeIslandCore

@MainActor
final class NotificationStoreTests: XCTestCase {
    func testArrivalsDeduplicationAndOrder() {
        let store = NotificationStore()
        let notif1 = AppNotification(
            id: "uuid-1",
            recordId: 1,
            bundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            sender: "Alice",
            body: "Msg 1",
            date: Date()
        )
        let notif2 = AppNotification(
            id: "uuid-2",
            recordId: 2,
            bundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            sender: "Bob",
            body: "Msg 2",
            date: Date()
        )

        store.handleArrivals([notif1, notif2])
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].id, "uuid-2") // Newest first
        XCTAssertEqual(store.items[1].id, "uuid-1")
        XCTAssertEqual(store.unreadCount, 2)

        // Arrive again with duplicate
        store.handleArrivals([notif1])
        XCTAssertEqual(store.items.count, 2)
    }

    func testMaxCapacityEnforced() {
        let store = NotificationStore()
        var batch: [AppNotification] = []
        for i in 1...60 {
            batch.append(AppNotification(
                id: "uuid-\(i)",
                recordId: Int64(i),
                bundleId: "net.whatsapp.WhatsApp",
                appName: "WhatsApp",
                sender: "Sender",
                body: "Body \(i)",
                date: Date()
            ))
        }

        store.handleArrivals(batch)
        XCTAssertEqual(store.items.count, NotificationStackPolicy.maxItems)
        XCTAssertEqual(store.items.first?.id, "uuid-60")
    }

    func testOpenNotificationRemovesAndCallsOpener() {
        let store = NotificationStore()
        var openedBundle: String?
        store.appOpener = { bundle in
            openedBundle = bundle
        }

        let notif = AppNotification(
            id: "uuid-open",
            recordId: 10,
            bundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            sender: "Alice",
            body: "Hi",
            date: Date()
        )
        store.handleArrivals([notif])

        store.open(id: "uuid-open")
        XCTAssertEqual(openedBundle, "net.whatsapp.WhatsApp")
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.unreadCount, 0)
    }

    func testClearAll() {
        let store = NotificationStore()
        let notif = AppNotification(
            id: "uuid-clear",
            recordId: 11,
            bundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            sender: "Alice",
            body: "Hi",
            date: Date()
        )
        store.handleArrivals([notif])
        XCTAssertEqual(store.items.count, 1)

        store.clearAll()
        XCTAssertEqual(store.items.count, 0)
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertFalse(store.isPeeking)
    }
}

