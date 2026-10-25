import SwiftUI
import AppKit
import CodeIslandCore

// MARK: - Avatar & Colors

public enum NotificationAvatarHelper {
    public static func initial(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    public static func color(for name: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.18, green: 0.80, blue: 0.44), // WhatsApp green
            Color(red: 0.20, green: 0.60, blue: 0.86), // Blue
            Color(red: 0.61, green: 0.35, blue: 0.71), // Purple
            Color(red: 0.95, green: 0.61, blue: 0.07), // Orange
            Color(red: 0.91, green: 0.30, blue: 0.24), // Coral
            Color(red: 0.10, green: 0.74, blue: 0.61), // Teal
        ]
        let hash = abs(name.hashValue)
        return palette[hash % palette.count]
    }
}

// MARK: - Peek View (for Notch compact bar)

public struct NotificationPeekView: View {
    let text: String
    var onTap: (() -> Void)? = nil

    public init(text: String, onTap: (() -> Void)? = nil) {
        self.text = text
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.78, blue: 0.35))
                    .frame(width: 17, height: 17)
                Image(systemName: "message.fill")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white)
            }

            MarqueeText(
                text: text,
                font: .system(size: 11, weight: .semibold, design: .rounded),
                color: .white
            )
            .frame(maxWidth: 320)

            Circle()
                .fill(Color(red: 0.15, green: 0.78, blue: 0.35))
                .frame(width: 6, height: 6)
                .shadow(color: Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.8), radius: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
                .overlay(
                    Capsule()
                        .strokeBorder(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.4), lineWidth: 0.8)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Single Notification Row

public struct NotificationRow: View {
    let item: AppNotification
    var onOpen: () -> Void
    var onRemove: () -> Void

    @State private var isHovered = false

    public init(item: AppNotification, onOpen: @escaping () -> Void, onRemove: @escaping () -> Void) {
        self.item = item
        self.onOpen = onOpen
        self.onRemove = onRemove
    }

    private var formattedTime: String {
        let interval = Date().timeIntervalSince(item.date)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let mins = max(1, Int(interval / 60))
            return "\(mins)m"
        } else if interval < 86400 {
            let hours = max(1, Int(interval / 3600))
            return "\(hours)h"
        } else {
            let days = max(1, Int(interval / 86400))
            return "\(days)d"
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 9) {
            // Sender Avatar
            ZStack {
                Circle()
                    .fill(NotificationAvatarHelper.color(for: item.sender))
                    .frame(width: 28, height: 28)
                Text(NotificationAvatarHelper.initial(for: item.sender))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.top, 1)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.sender)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let sub = item.subtitle, !sub.isEmpty, sub != item.sender {
                        Text("(\(sub))")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(formattedTime)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    // Delete single button
                    if isHovered {
                        Button(action: onRemove) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(3)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .help("Hapus notifikasi")
                        .transition(.opacity)
                    }
                }

                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onOpen()
        }
    }
}

// MARK: - Stacked Card (for Tab ALL)

public struct NotificationStackCard: View {
    @Bindable var store: NotificationStore
    var onOpenFullTab: () -> Void

    @State private var isStackExpanded = false
    @State private var isClearConfirming = false

    public init(store: NotificationStore, onOpenFullTab: @escaping () -> Void) {
        self.store = store
        self.onOpenFullTab = onOpenFullTab
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Section Header
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.78, blue: 0.35))
                        .frame(width: 14, height: 14)
                    Image(systemName: "message.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("WhatsApp")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))

                Text("\(store.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.25)))
                    .foregroundStyle(Color(red: 0.15, green: 0.78, blue: 0.35))

                Spacer()

                // Clear All Button (with 2-tap confirmation)
                if isClearConfirming {
                    HStack(spacing: 4) {
                        Button("Konfirmasi?") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.clearAll()
                                isClearConfirming = false
                            }
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)

                        Button("Batal") {
                            withAnimation { isClearConfirming = false }
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        withAnimation { isClearConfirming = true }
                    }) {
                        Text("Hapus Semua")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Hapus semua notifikasi WhatsApp")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)

            // Content: single row, or stacked cards, or expanded list
            if store.items.count == 1, let first = store.items.first {
                NotificationRow(
                    item: first,
                    onOpen: { store.open(id: first.id) },
                    onRemove: { store.remove(id: first.id) }
                )
            } else if isStackExpanded {
                VStack(spacing: 4) {
                    ForEach(store.items) { item in
                        NotificationRow(
                            item: item,
                            onOpen: { store.open(id: item.id) },
                            onRemove: { store.remove(id: item.id) }
                        )
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isStackExpanded = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                            Text("Tutup Stack")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } else if let topItem = store.items.first {
                // Stack preview
                ZStack(alignment: .bottom) {
                    // Back card 2
                    if store.items.count >= 3 {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.02))
                            .frame(height: 48)
                            .offset(y: 8)
                            .scaleEffect(0.92, anchor: .bottom)
                    }

                    // Back card 1
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 52)
                        .offset(y: 4)
                        .scaleEffect(0.96, anchor: .bottom)

                    // Front card
                    NotificationRow(
                        item: topItem,
                        onOpen: {
                            // When stack is collapsed, clicking expands the stack
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                isStackExpanded = true
                            }
                        },
                        onRemove: {
                            store.remove(id: topItem.id)
                        }
                    )
                    .overlay(alignment: .bottomTrailing) {
                        // Badge indicating stacked items
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                isStackExpanded = true
                            }
                        }) {
                            HStack(spacing: 3) {
                                Text("+\(store.items.count - 1) lainnya")
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 7.5, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.85))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                            )
                            .foregroundStyle(Color(red: 0.15, green: 0.78, blue: 0.35))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                    }
                }
                .padding(.bottom, store.items.count >= 3 ? 8 : 4)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Dedicated Notification Tab View

public struct NotificationListView: View {
    @Bindable var store: NotificationStore
    @State private var isClearConfirming = false

    public init(store: NotificationStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.78, blue: 0.35))
                        .frame(width: 16, height: 16)
                    Image(systemName: "message.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("WhatsApp Notifications")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                if !store.items.isEmpty {
                    Text("\(store.items.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.25)))
                        .foregroundStyle(Color(red: 0.15, green: 0.78, blue: 0.35))
                }

                Spacer()

                if !store.items.isEmpty {
                    if isClearConfirming {
                        HStack(spacing: 4) {
                            Button("Konfirmasi Hapus?") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.clearAll()
                                    isClearConfirming = false
                                }
                            }
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)

                            Button("Batal") {
                                withAnimation { isClearConfirming = false }
                            }
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button(action: {
                            withAnimation { isClearConfirming = true }
                        }) {
                            Text("Hapus Semua")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Hapus semua notifikasi WhatsApp")
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Content
            if store.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 30)

                    Text("Belum ada notifikasi")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Notifikasi pesan WhatsApp Desktop akan muncul di sini.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        ForEach(store.items) { item in
                            NotificationRow(
                                item: item,
                                onOpen: { store.open(id: item.id) },
                                onRemove: { store.remove(id: item.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            store.markAllSeen()
        }
    }
}

// MARK: - Settings Section

struct WhatsAppNotificationsSection: View {
    var appState: AppState
    @AppStorage(SettingsKey.notificationsEnabled) private var notificationsEnabled = SettingsDefaults.notificationsEnabled
    @AppStorage(SettingsKey.notificationShowBody) private var notificationShowBody = SettingsDefaults.notificationShowBody
    @AppStorage(SettingsKey.notificationAutoClearOnRead) private var notificationAutoClearOnRead = SettingsDefaults.notificationAutoClearOnRead

    @State private var hasFullDiskAccess = NotificationCenterWatcher.isDatabaseAccessible()

    init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Section("WhatsApp Notifications") {
            Toggle("Tampilkan notifikasi WhatsApp Desktop", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        appState.notifications.startWatching()
                    } else {
                        appState.notifications.stopWatching()
                    }
                }

            if notificationsEnabled {
                HStack {
                    if hasFullDiskAccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Full Disk Access diberikan")
                            .font(.system(size: 12))
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Butuh Full Disk Access untuk membaca notifikasi")
                            .font(.system(size: 12))
                        Spacer()
                        Button("Buka Pengaturan") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                .onAppear {
                    hasFullDiskAccess = NotificationCenterWatcher.isDatabaseAccessible()
                }

                Toggle("Tampilkan isi pesan", isOn: $notificationShowBody)
                Toggle("Hapus otomatis saat dibaca di WhatsApp", isOn: $notificationAutoClearOnRead)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pengujian Tampilan:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Uji Coba 1 Pesan") {
                            appState.notifications.sendTestNotification(count: 1)
                        }
                        .controlSize(.small)

                        Button("Uji Coba 3 Pesan (Stack)") {
                            appState.notifications.sendTestNotification(count: 3)
                        }
                        .controlSize(.small)
                    }

                    Text("Tombol di atas memicu notifikasi tiruan agar Anda bisa langsung melihat efek notch peek 1 detik, badge di wing kanan, tampilan row / stack di tab ALL, dan tab NOTIF.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                Text("Notifikasi hanya disimpan di memori sementara (maks. 50 pesan) dan tidak pernah ditulis ke penyimpanan disk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
