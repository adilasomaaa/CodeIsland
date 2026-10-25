import Foundation
import Observation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.codeisland", category: "Spotify")

struct SpotifyTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval
    var isPlaying: Bool = true
    var artworkURL: String? = nil

    var identity: String { "\(title)\u{1f}\(artist)\u{1f}\(album)" }
}

struct SpotifyLyrics: Sendable {
    let plain: String
    let timedLines: [(time: TimeInterval, text: String)]

    static func parse(synced: String?, plain: String?) -> SpotifyLyrics? {
        let timed = (synced ?? "").components(separatedBy: .newlines).compactMap { line -> (TimeInterval, String)? in
            guard let end = line.firstIndex(of: "]"), line.first == "[" else { return nil }
            let stamp = line[line.index(after: line.startIndex)..<end]
            let parts = stamp.split(separator: ":")
            guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
            let text = String(line[line.index(after: end)...]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return (minutes * 60 + seconds, text)
        }.sorted { $0.0 < $1.0 }

        let cleanPlain = (plain ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !timed.isEmpty || !cleanPlain.isEmpty else { return nil }
        return SpotifyLyrics(plain: cleanPlain, timedLines: timed)
    }

    /// Returns the active lyric line for `position`.
    /// `leadOffset` defaults to 0.5s (500ms) so lyrics display slightly ahead of singing.
    func line(at position: TimeInterval, leadOffset: TimeInterval = 0.5) -> String? {
        let target = position + leadOffset
        return timedLines.last(where: { $0.time <= target })?.text
    }
}

@MainActor
@Observable
final class SpotifyNowPlayingMonitor {
    private(set) var track: SpotifyTrack?
    private(set) var lyrics: SpotifyLyrics?
    private(set) var currentLyricLine: String?
    private(set) var isLoadingLyrics = false

    private var lastRequestedTrackID: String?
    private var polling = false

    func togglePlayPause() {
        AppleScriptRunner.current.launch(#"tell application "Spotify" to playpause"#)
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await refreshNow()
        }
    }

    func previousTrack() {
        AppleScriptRunner.current.launch(#"tell application "Spotify" to previous track"#)
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await refreshNow()
        }
    }

    func nextTrack() {
        AppleScriptRunner.current.launch(#"tell application "Spotify" to next track"#)
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await refreshNow()
        }
    }

    func refreshNow() async {
        let result = await Task.detached(priority: .utility) {
            Self.readSpotifyTrack()
        }.value
        update(track: result)
    }

    func pollContinuously() async {
        guard !polling else { return }
        polling = true
        defer { polling = false }

        while !Task.isCancelled {
            let result = await Task.detached(priority: .utility) {
                Self.readSpotifyTrack()
            }.value
            update(track: result)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func update(track next: SpotifyTrack?) {
        guard let next else {
            track = nil
            currentLyricLine = nil
            lyrics = nil
            lastRequestedTrackID = nil
            return
        }

        track = next
        currentLyricLine = lyrics?.line(at: next.position)
        guard lastRequestedTrackID != next.identity else { return }

        lastRequestedTrackID = next.identity
        lyrics = nil
        currentLyricLine = nil
        isLoadingLyrics = true
        Task { [weak self] in
            let result = await Self.fetchLyrics(for: next)
            guard let self, self.track?.identity == next.identity else { return }
            self.lyrics = result
            self.currentLyricLine = result?.line(at: self.track?.position ?? 0)
            self.isLoadingLyrics = false
        }
    }

    nonisolated private static func readSpotifyTrack() -> SpotifyTrack? {
        let source = #"""
        if application "Spotify" is not running then return ""
        tell application "Spotify"
            if player state is stopped then return ""
            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set trackDuration to (duration of current track) as integer
            set playPosition to (round ((player position) * 1000)) as integer
            set isPlaying to (player state is playing)
            set artUrl to ""
            try
                set artUrl to artwork url of current track
            end try
            return trackName & tab & artistName & tab & albumName & tab & (trackDuration as text) & tab & (playPosition as text) & tab & (isPlaying as text) & tab & artUrl
        end tell
        """#
        guard let output = AppleScriptRunner.current.evaluate(source, 5) else { return nil }
        let track = parseTrack(from: output)
        if track == nil && !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log.debug("Failed to parse Spotify output: \(output, privacy: .public)")
        }
        return track
    }

    nonisolated static func parseTrack(from output: String) -> SpotifyTrack? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let values = trimmed.components(separatedBy: "\t")
        guard values.count >= 5 else { return nil }

        let title = values[0].trimmingCharacters(in: .whitespaces)
        let artist = values[1].trimmingCharacters(in: .whitespaces)
        let album = values[2].trimmingCharacters(in: .whitespaces)

        guard !title.isEmpty, !artist.isEmpty else { return nil }

        guard let durationMs = parseNumber(values[3]), durationMs > 0 else { return nil }
        let duration = durationMs / 1000.0

        let rawPos = values[4].trimmingCharacters(in: .whitespaces)
        guard !rawPos.isEmpty else { return nil }

        let position: TimeInterval
        if rawPos.contains(".") || rawPos.contains(",") {
            guard let posSec = parseNumber(rawPos), posSec >= 0 else { return nil }
            position = posSec
        } else {
            guard let posMs = parseNumber(rawPos), posMs >= 0 else { return nil }
            position = posMs / 1000.0
        }

        let isPlaying: Bool
        if values.count >= 6 {
            let stateStr = values[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            isPlaying = (stateStr == "true")
        } else {
            isPlaying = true
        }

        let artworkURL: String?
        if values.count >= 7 {
            let rawUrl = values[6].trimmingCharacters(in: .whitespacesAndNewlines)
            artworkURL = rawUrl.isEmpty ? nil : rawUrl
        } else {
            artworkURL = nil
        }

        return SpotifyTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            isPlaying: isPlaying,
            artworkURL: artworkURL
        )
    }

    nonisolated static func parseNumber(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let val = Double(trimmed) {
            return val
        }
        let dotReplaced = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(dotReplaced)
    }

    nonisolated private static func fetchLyrics(for track: SpotifyTrack) async -> SpotifyLyrics? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(track.title) \(track.artist)")]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("CodeIsland/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let results = try JSONDecoder().decode([LRCLIBEntry].self, from: data)
            let titleKey = normalize(track.title)
            let artistKey = normalize(track.artist)
            let best = results.first(where: {
                normalize($0.trackName) == titleKey && normalize($0.artistName).contains(artistKey)
            })
            return SpotifyLyrics.parse(synced: best?.syncedLyrics, plain: best?.plainLyrics)
        } catch {
            return nil
        }
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LRCLIBEntry: Decodable {
    let trackName: String
    let artistName: String
    let plainLyrics: String?
    let syncedLyrics: String?
}

struct SpotifyArtworkView: View {
    let urlString: String?
    let size: CGFloat
    var cornerRadius: CGFloat = 6

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var fallbackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.12, green: 0.82, blue: 0.40).opacity(0.15))
            Image(systemName: "music.note")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Color(red: 0.12, green: 0.82, blue: 0.40))
        }
    }
}

struct SpotifyNowPlayingView: View {
    let monitor: SpotifyNowPlayingMonitor

    private var lyricLines: [String] {
        guard let lyrics = monitor.lyrics else { return [] }
        if !lyrics.timedLines.isEmpty { return lyrics.timedLines.map(\.text) }
        return lyrics.plain.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    private var activeLineIndex: Int {
        guard let line = monitor.currentLyricLine else { return -1 }
        return lyricLines.firstIndex(of: line) ?? -1
    }

    @ViewBuilder
    private func trackControls(track: SpotifyTrack) -> some View {
        HStack(spacing: 8) {
            Button {
                monitor.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Previous Track")

            Button {
                monitor.togglePlayPause()
            } label: {
                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(red: 0.12, green: 0.82, blue: 0.40)))
            }
            .buttonStyle(.plain)
            .help(track.isPlaying ? "Pause" : "Play")

            Button {
                monitor.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Next Track")

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(track.isPlaying ? Color(red: 0.12, green: 0.82, blue: 0.40) : Color.white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(track.isPlaying ? "PLAY" : "PAUSE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    @ViewBuilder
    private func leftColumn(track: SpotifyTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SpotifyArtworkView(urlString: track.artworkURL, size: 40, cornerRadius: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            VStack(spacing: 2) {
                ProgressView(value: track.position, total: max(track.duration, 1))
                    .tint(Color(red: 0.12, green: 0.82, blue: 0.40))
                HStack {
                    Text(Self.time(track.position))
                    Spacer()
                    Text(Self.time(track.duration))
                }
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            }

            trackControls(track: track)
        }
        .frame(maxWidth: 200, alignment: .leading)
    }

    @ViewBuilder
    private var lyricsScrollList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lyricLines.enumerated()), id: \.offset) { index, line in
                        let isActive = index == activeLineIndex
                        HStack(spacing: 5) {
                            if isActive {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.82, blue: 0.40))
                                    .frame(width: 3.5, height: 3.5)
                            }
                            Text(line)
                                .font(.system(size: 10, weight: isActive ? .bold : .regular, design: .monospaced))
                                .foregroundStyle(isActive ? .white : .white.opacity(0.45))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isActive
                                ? Color(red: 0.12, green: 0.82, blue: 0.40).opacity(0.18)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                        .id(index)
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(height: 72)
            .scrollIndicators(.hidden)
            .onChange(of: activeLineIndex) { _, index in
                guard index >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
            .onAppear {
                if activeLineIndex >= 0 {
                    proxy.scrollTo(activeLineIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var rightLyricsColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("LYRICS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(red: 0.12, green: 0.82, blue: 0.40))
                Spacer()
                Text("LRCLIB")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            if monitor.isLoadingLyrics {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding lyrics…")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 72)
            } else if lyricLines.isEmpty {
                Text("Lyrics aren’t available.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
            } else {
                lyricsScrollList
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var emptyPlaybackView: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.12, green: 0.82, blue: 0.40))
            Text("No song is playing")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text("Start playback in Spotify desktop to see the track and lyrics here.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        Group {
            if let track = monitor.track {
                HStack(alignment: .top, spacing: 12) {
                    leftColumn(track: track)

                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 1, height: 92)

                    rightLyricsColumn
                }
                .padding(10)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                emptyPlaybackView
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static func time(_ interval: TimeInterval) -> String {
        guard interval.isFinite else { return "0:00" }
        let seconds = max(0, Int(interval))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct SpotifyMiniCard: View {
    let monitor: SpotifyNowPlayingMonitor
    var onOpenFull: (() -> Void)? = nil

    var body: some View {
        if let track = monitor.track {
            HStack(spacing: 10) {
                SpotifyArtworkView(urlString: track.artworkURL, size: 36, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))

                        Text(track.artist)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)

                        Spacer()

                        // Controls: Previous, Play/Pause, Next
                        HStack(spacing: 4) {
                            Button {
                                monitor.previousTrack()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .help("Previous Track")

                            Button {
                                monitor.togglePlayPause()
                            } label: {
                                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(track.isPlaying ? Color(red: 0.12, green: 0.82, blue: 0.40) : .white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .help(track.isPlaying ? "Pause" : "Play")

                            Button {
                                monitor.nextTrack()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .help("Next Track")
                        }
                    }

                    ProgressView(value: track.position, total: max(track.duration, 1))
                        .tint(Color(red: 0.12, green: 0.82, blue: 0.40))
                        .scaleEffect(x: 1, y: 0.5, anchor: .center)

                    if let line = monitor.currentLyricLine, !line.isEmpty {
                        Text(line)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(red: 0.12, green: 0.82, blue: 0.40).opacity(0.2), lineWidth: 1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onOpenFull?()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .help("Click to open Spotify tab")
        }
    }
}
