import Foundation
import Observation
import SwiftUI

struct SpotifyTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval

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

    func line(at position: TimeInterval) -> String? {
        timedLines.last(where: { $0.time <= position })?.text
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
            if player state is not playing then return ""
            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set trackDuration to duration of current track
            set playPosition to player position
            return trackName & tab & artistName & tab & albumName & tab & trackDuration & tab & playPosition
        end tell
        """#
        guard let output = AppleScriptRunner.current.evaluate(source, 2) else { return nil }
        let values = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t")
        guard values.count >= 5,
              let durationMilliseconds = Double(values[3]),
              let position = Double(values[4]),
              !values[0].isEmpty, !values[1].isEmpty else { return nil }
        return SpotifyTrack(
            title: values[0], artist: values[1], album: values[2],
            duration: durationMilliseconds / 1000, position: position
        )
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

struct SpotifyLyricsPanel: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.82, blue: 0.40))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(monitor.track?.title ?? "Spotify")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text([monitor.track?.artist, monitor.track?.album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Text("SPOTIFY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color(red: 0.12, green: 0.82, blue: 0.40))
            }

            if monitor.isLoadingLyrics {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small).tint(.white.opacity(0.7))
                    Text("Loading lyrics…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if lyricLines.isEmpty {
                Text("Lyrics aren’t available for this track.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(lyricLines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: 12, weight: index == activeLineIndex ? .semibold : .regular))
                                    .foregroundStyle(index == activeLineIndex ? .white : .white.opacity(0.52))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 116)
                    .scrollIndicators(.hidden)
                    .onChange(of: activeLineIndex) { _, index in
                        guard index >= 0 else { return }
                        withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
                    }
                    .onAppear {
                        if activeLineIndex >= 0 { proxy.scrollTo(activeLineIndex, anchor: .center) }
                    }
                }
            }

            HStack {
                Spacer()
                Text("Lyrics by LRCLIB")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(14)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }
}
