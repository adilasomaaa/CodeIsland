import AppKit
import Foundation
import Observation
import CodeIslandCore

@MainActor
@Observable
public final class NotificationStore {
    public private(set) var items: [AppNotification] = []
    public private(set) var unreadCount: Int = 0
    public private(set) var isPeeking: Bool = false
    public private(set) var currentPeekText: String?

    @ObservationIgnored
    private var peekTask: Task<Void, Never>?

    @ObservationIgnored
    private var watcher: NotificationCenterWatcher?

    /// Closure invoked when opening an application bundle ID. Customizable for testing.
    @ObservationIgnored
    public var appOpener: ((String) -> Void)?

    public init() {}

    deinit {
        peekTask?.cancel()
    }

    /// Attaches the background watcher and binds notification handlers.
    public func startWatching(watcher: NotificationCenterWatcher? = nil) {
        let w = watcher ?? NotificationCenterWatcher()
        self.watcher = w

        w.onNewNotifications = { [weak self] arrivals in
            Task { @MainActor [weak self] in
                self?.handleArrivals(arrivals)
            }
        }

        w.onRemovedRecordIds = { [weak self] removed in
            Task { @MainActor [weak self] in
                self?.handleRemovedRecordIds(removed)
            }
        }

        w.start()
    }

    public func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    /// Ingests newly arrived notifications, trims storage, and triggers the 1-second notch peek.
    public func handleArrivals(_ arrivals: [AppNotification]) {
        guard !arrivals.isEmpty else { return }

        // Deduplicate against existing items by id
        let existingIds = Set(items.map(\.id))
        let fresh = arrivals.filter { !existingIds.contains($0.id) }
        guard !fresh.isEmpty else { return }

        // Newest items first
        items.insert(contentsOf: fresh.reversed(), at: 0)

        // Enforce max in-memory limit
        if items.count > NotificationStackPolicy.maxItems {
            items = Array(items.prefix(NotificationStackPolicy.maxItems))
        }

        unreadCount = min(items.count, unreadCount + fresh.count)

        // 1-second notch peek
        triggerPeek(for: fresh)
    }

    /// Triggers the 1-second highest-priority peek.
    public func triggerPeek(for arrivals: [AppNotification]) {
        peekTask?.cancel()
        currentPeekText = NotificationStackPolicy.peekText(for: arrivals)
        isPeeking = true

        peekTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(NotificationStackPolicy.peekDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.isPeeking = false
            self?.currentPeekText = nil
        }
    }

    /// Removes a notification by ID.
    public func remove(id: String) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: idx)
            if unreadCount > 0 {
                unreadCount -= 1
            }
        }
    }

    /// Clears all stored notifications.
    public func clearAll() {
        peekTask?.cancel()
        isPeeking = false
        currentPeekText = nil
        items.removeAll()
        unreadCount = 0
    }

    /// Handles click on a notification: removes the notification and brings WhatsApp to the foreground.
    public func open(id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let bundleId = item.bundleId
        remove(id: id)

        if let opener = appOpener {
            opener(bundleId)
            return
        }

        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: appUrl, configuration: .init(), completionHandler: nil)
        } else if let fallback = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.whatsapp.WhatsApp") {
            NSWorkspace.shared.openApplication(at: fallback, configuration: .init(), completionHandler: nil)
        }
    }

    /// Marks all notifications as seen (resets unread badge).
    public func markAllSeen() {
        unreadCount = 0
    }

    /// Syncs records pruned from Notification Center (e.g. read in WhatsApp).
    public func handleRemovedRecordIds(_ removed: Set<Int64>) {
        guard !removed.isEmpty else { return }
        let beforeCount = items.count
        items.removeAll { removed.contains($0.recordId) }
        let removedCount = beforeCount - items.count
        if removedCount > 0 {
            unreadCount = max(0, unreadCount - removedCount)
        }
    }

    /// Checks if active notifications have been dismissed or read in Notification Center.
    public func syncPruned() {
        let activeIds = items.map(\.recordId)
        watcher?.checkPruned(activeRecordIds: activeIds)
    }

    /// Sends a mock notification for immediate testing of the peek, stack card, and tabs.
    public func sendTestNotification(count: Int = 1) {
        if count == 1 {
            let testNotif = AppNotification(
                id: UUID().uuidString,
                recordId: Int64(Date().timeIntervalSince1970),
                bundleId: "net.whatsapp.WhatsApp",
                appName: "WhatsApp",
                sender: "Budi Santoso",
                subtitle: "Keluarga",
                body: "Halo! Ini pesan uji coba notifikasi WhatsApp di notch CodeIsland.",
                date: Date()
            )
            handleArrivals([testNotif])
        } else {
            var batch: [AppNotification] = []
            for i in 1...count {
                batch.append(AppNotification(
                    id: UUID().uuidString,
                    recordId: Int64(Date().timeIntervalSince1970) + Int64(i),
                    bundleId: "net.whatsapp.WhatsApp",
                    appName: "WhatsApp",
                    sender: "Kontak \(i)",
                    subtitle: nil,
                    body: "Pesan uji coba \(i) dari WhatsApp.",
                    date: Date()
                ))
            }
            handleArrivals(batch)
        }
    }
}

