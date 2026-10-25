import XCTest
@testable import CodeIsland

final class SpotifyNowPlayingTests: XCTestCase {
    func testParseTrackWithIntegerMilliseconds() {
        let output = "Guts Over Fear\tEminem\tSHADYXV\t301000\t183766\n"
        let track = SpotifyNowPlayingMonitor.parseTrack(from: output)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.title, "Guts Over Fear")
        XCTAssertEqual(track?.artist, "Eminem")
        XCTAssertEqual(track?.album, "SHADYXV")
        XCTAssertEqual(track?.duration, 301.0)
        XCTAssertEqual(track?.position, 183.766)
    }

    func testParseTrackWithDecimalCommaPosition() {
        // In European / Indonesian locales, AppleScript coerces reals with decimal comma
        let output = "Lose Yourself\tEminem\tCurtain Call\t326000\t45,217\n"
        let track = SpotifyNowPlayingMonitor.parseTrack(from: output)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.title, "Lose Yourself")
        XCTAssertEqual(track?.artist, "Eminem")
        XCTAssertEqual(track?.album, "Curtain Call")
        XCTAssertEqual(track?.duration, 326.0)
        XCTAssertEqual(track?.position, 45.217)
    }

    func testParseTrackWithDecimalDotPosition() {
        let output = "Lose Yourself\tEminem\tCurtain Call\t326000\t45.217\n"
        let track = SpotifyNowPlayingMonitor.parseTrack(from: output)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.title, "Lose Yourself")
        XCTAssertEqual(track?.artist, "Eminem")
        XCTAssertEqual(track?.album, "Curtain Call")
        XCTAssertEqual(track?.duration, 326.0)
        XCTAssertEqual(track?.position, 45.217)
    }

    func testParseTrackEmptyOrWhitespace() {
        XCTAssertNil(SpotifyNowPlayingMonitor.parseTrack(from: ""))
        XCTAssertNil(SpotifyNowPlayingMonitor.parseTrack(from: "   \n\t  \n"))
    }

    func testParseTrackMalformedOrMissingFields() {
        // Fewer than 5 tabs
        XCTAssertNil(SpotifyNowPlayingMonitor.parseTrack(from: "Title\tArtist\tAlbum\t10000"))
        // Non-numeric duration or position
        XCTAssertNil(SpotifyNowPlayingMonitor.parseTrack(from: "Title\tArtist\tAlbum\tnot_a_num\t10000"))
        XCTAssertNil(SpotifyNowPlayingMonitor.parseTrack(from: "Title\tArtist\tAlbum\t10000\tnot_a_num"))
        // Empty title or artist
        XCTAssertNil(SpotifyNowPlayingMonitor.parseTrack(from: "\tArtist\tAlbum\t10000\t1000"))
        XCTAssertNil(SpotifyNowPlayingMonitor.parseTrack(from: "Title\t\tAlbum\t10000\t1000"))
    }

    func testParseNumberHelper() {
        XCTAssertEqual(SpotifyNowPlayingMonitor.parseNumber("123"), 123.0)
        XCTAssertEqual(SpotifyNowPlayingMonitor.parseNumber("  123.45  "), 123.45)
        XCTAssertEqual(SpotifyNowPlayingMonitor.parseNumber("123,45"), 123.45)
        XCTAssertNil(SpotifyNowPlayingMonitor.parseNumber("invalid"))
        XCTAssertNil(SpotifyNowPlayingMonitor.parseNumber(""))
    }

    func testParseTrackWithPlayerStatePlayingAndPaused() {
        let playingOutput = "Guts Over Fear\tEminem\tSHADYXV\t301000\t183766\ttrue\n"
        let playingTrack = SpotifyNowPlayingMonitor.parseTrack(from: playingOutput)
        XCTAssertNotNil(playingTrack)
        XCTAssertTrue(playingTrack?.isPlaying ?? false)

        let pausedOutput = "Guts Over Fear\tEminem\tSHADYXV\t301000\t183766\tfalse\n"
        let pausedTrack = SpotifyNowPlayingMonitor.parseTrack(from: pausedOutput)
        XCTAssertNotNil(pausedTrack)
        XCTAssertFalse(pausedTrack?.isPlaying ?? true)
    }

    func testParseTrackWithArtworkURL() {
        let output = "drop dead\tOlivia Rodrigo\tthe cure\t224999\t186166\ttrue\thttps://i.scdn.co/image/ab67616d0000b273\n"
        let track = SpotifyNowPlayingMonitor.parseTrack(from: output)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.title, "drop dead")
        XCTAssertEqual(track?.artist, "Olivia Rodrigo")
        XCTAssertEqual(track?.album, "the cure")
        XCTAssertEqual(track?.duration, 224.999)
        XCTAssertEqual(track?.position, 186.166)
        XCTAssertTrue(track?.isPlaying ?? false)
        XCTAssertEqual(track?.artworkURL, "https://i.scdn.co/image/ab67616d0000b273")
    }

    func testLyricLineRetrievalWithLeadOffset() {
        let syncedLRC = """
        [00:10.00] Line one
        [00:20.00] Line two
        """
        guard let lyrics = SpotifyLyrics.parse(synced: syncedLRC, plain: nil) else {
            XCTFail("Failed to parse lyrics")
            return
        }

        // Before 9.5s (more than 0.5s before Line one at 10.0s) -> no line
        XCTAssertNil(lyrics.line(at: 9.4))

        // At 9.5s (exactly 0.5s / 500ms before 10.0s) -> Line one activates!
        XCTAssertEqual(lyrics.line(at: 9.5), "Line one")

        // Between 10.0s and 19.4s -> Line one
        XCTAssertEqual(lyrics.line(at: 10.0), "Line one")
        XCTAssertEqual(lyrics.line(at: 19.4), "Line one")

        // At 19.5s (0.5s before Line two at 20.0s) -> Line two activates!
        XCTAssertEqual(lyrics.line(at: 19.5), "Line two")
    }
}

