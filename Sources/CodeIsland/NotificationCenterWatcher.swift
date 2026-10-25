import Foundation
import SQLite3
import CodeIslandCore

/// Observes macOS Notification Center SQLite database for WhatsApp notifications.
public final class NotificationCenterWatcher: @unchecked Sendable {
    public static let standardDbPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Group Containers/group.com.apple.usernoted/db2/db"
    }()

    public static let standardWalPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Group Containers/group.com.apple.usernoted/db2/db-wal"
    }()

    private let dbPath: String
    private let walPath: String
    private let queue = DispatchQueue(label: "com.codeisland.notification-watcher", qos: .utility)

    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var dirSource: DispatchSourceFileSystemObject?
    private var dirDescriptor: Int32 = -1
    private var pollTimer: DispatchSourceTimer?
    private var debounceWorkItem: DispatchWorkItem?

    public var onNewNotifications: (([AppNotification]) -> Void)?
    public var onRemovedRecordIds: ((Set<Int64>) -> Void)?

    private var lastSeenRecordId: Int64 = 0
    private var isStarted = false

    public init(dbPath: String = NotificationCenterWatcher.standardDbPath, walPath: String = NotificationCenterWatcher.standardWalPath) {
        self.dbPath = dbPath
        self.walPath = walPath
    }

    deinit {
        stop()
    }

    /// Checks whether the notification database is accessible (Full Disk Access granted).
    public static func isDatabaseAccessible(dbPath: String = NotificationCenterWatcher.standardDbPath) -> Bool {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            sqlite3_close(db)
            return true
        }
        sqlite3_close(db)
        return false
    }

    /// Start watching for new notifications.
    public func start(seedFromLatest: Bool = true) {
        queue.async { [weak self] in
            guard let self, !self.isStarted else { return }
            self.isStarted = true

            if seedFromLatest {
                self.lastSeenRecordId = self.fetchLatestRecordId()
            }

            self.attachFileWatch()
            self.startPeriodicTimer()
        }
    }

    /// Stop watching.
    public func stop() {
        queue.sync {
            self.isStarted = false
            self.detachFileWatch()
            self.stopPeriodicTimer()
            self.debounceWorkItem?.cancel()
            self.debounceWorkItem = nil
        }
    }

    private func startPeriodicTimer() {
        stopPeriodicTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 3.0, repeating: 3.0)
        timer.setEventHandler { [weak self] in
            self?.pollOnce()
        }
        timer.resume()
        self.pollTimer = timer
    }

    private func stopPeriodicTimer() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func attachFileWatch() {
        detachFileWatch()

        // 1. Watch directory containing db and db-wal
        let dirPath = (dbPath as NSString).deletingLastPathComponent
        if FileManager.default.fileExists(atPath: dirPath) {
            dirDescriptor = open(dirPath, O_EVTONLY)
            if dirDescriptor >= 0 {
                let dSource = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: dirDescriptor,
                    eventMask: [.write, .extend, .delete, .rename],
                    queue: queue
                )
                dSource.setEventHandler { [weak self] in
                    self?.schedulePoll()
                }
                dSource.setCancelHandler { [fd = dirDescriptor] in
                    if fd >= 0 { close(fd) }
                }
                dSource.resume()
                self.dirSource = dSource
            }
        }

        // 2. Watch wal file or db file directly
        let watchPath = FileManager.default.fileExists(atPath: walPath) ? walPath : dbPath
        guard FileManager.default.fileExists(atPath: watchPath) else { return }

        fileDescriptor = open(watchPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let data = source.data
            if data.contains(.delete) || data.contains(.rename) {
                // WAL recreated during checkpoint; reattach
                self.attachFileWatch()
            }
            self.schedulePoll()
        }

        source.setCancelHandler { [fd = fileDescriptor] in
            if fd >= 0 { close(fd) }
        }

        source.resume()
        self.fileSource = source
    }

    private func detachFileWatch() {
        if let source = fileSource {
            source.cancel()
            fileSource = nil
        }
        fileDescriptor = -1

        if let dSource = dirSource {
            dSource.cancel()
            dirSource = nil
        }
        dirDescriptor = -1
    }

    public func schedulePoll(delayMs: Int = 250) {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.pollOnce()
        }
        debounceWorkItem = item
        queue.asyncAfter(deadline: .now() + .milliseconds(delayMs), execute: item)
    }

    /// Poll database for new records.
    public func pollOnce() {
        let (newItems, maxId) = fetchNewNotifications(since: lastSeenRecordId)
        if maxId > lastSeenRecordId {
            lastSeenRecordId = maxId
        }
        if !newItems.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onNewNotifications?(newItems)
            }
        }
    }

    /// Check if previously tracked records still exist in the database.
    public func checkPruned(activeRecordIds: [Int64]) {
        guard !activeRecordIds.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            let stillExisting = self.fetchExistingRecordIds(from: activeRecordIds)
            let removed = Set(activeRecordIds).subtracting(stillExisting)
            if !removed.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onRemovedRecordIds?(removed)
                }
            }
        }
    }

    // MARK: - SQLite queries

    private func openDatabase() -> OpaquePointer? {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        return db
    }

    private func fetchLatestRecordId() -> Int64 {
        guard let db = openDatabase() else { return 0 }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "SELECT MAX(rec_id) FROM record;"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int64(stmt, 0)
        }
        return 0
    }

    private func fetchNewNotifications(since recordId: Int64) -> (items: [AppNotification], maxRecordId: Int64) {
        guard let db = openDatabase() else { return ([], recordId) }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = """
        SELECT r.rec_id, r.delivered_date, r.uuid, r.data, a.identifier
        FROM record r
        INNER JOIN app a ON r.app_id = a.app_id
        WHERE r.rec_id > ?
          AND (
            a.identifier IN ('net.whatsapp.WhatsApp', 'desktop.WhatsApp', 'net.whatsapp.WhatsApp.desktop')
            OR LOWER(a.identifier) LIKE '%whatsapp%'
          )
        ORDER BY r.rec_id ASC
        LIMIT 50;
        """

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return ([], recordId)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, recordId)

        var results: [AppNotification] = []
        var highestId = recordId

        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(stmt, 0)
            if rowId > highestId {
                highestId = rowId
            }
            let deliveredDate = sqlite3_column_double(stmt, 1)

            var uuidData: Data? = nil
            if let uuidBlob = sqlite3_column_blob(stmt, 2) {
                let uuidBytes = sqlite3_column_bytes(stmt, 2)
                if uuidBytes > 0 {
                    uuidData = Data(bytes: uuidBlob, count: Int(uuidBytes))
                }
            }

            guard let dataBlob = sqlite3_column_blob(stmt, 3) else { continue }
            let dataBytes = sqlite3_column_bytes(stmt, 3)
            guard dataBytes > 0 else { continue }
            let payloadData = Data(bytes: dataBlob, count: Int(dataBytes))

            guard let rawBundle = sqlite3_column_text(stmt, 4) else { continue }
            let bundleId = String(cString: rawBundle)

            if let item = NotificationRecordDecoder.decode(
                recordId: rowId,
                uuidBytes: uuidData,
                dataBlob: payloadData,
                bundleId: bundleId,
                deliveredDateRaw: deliveredDate
            ) {
                results.append(item)
            }
        }

        return (results, highestId)
    }

    private func fetchExistingRecordIds(from ids: [Int64]) -> Set<Int64> {
        guard !ids.isEmpty, let db = openDatabase() else { return [] }
        defer { sqlite3_close(db) }

        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let query = "SELECT rec_id FROM record WHERE rec_id IN (\(placeholders));"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        for (index, id) in ids.enumerated() {
            sqlite3_bind_int64(stmt, Int32(index + 1), id)
        }

        var existing: Set<Int64> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            existing.insert(sqlite3_column_int64(stmt, 0))
        }
        return existing
    }
}

