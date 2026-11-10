import Foundation
import Testing
@testable import Wianu

@MainActor
struct AutomaticContinueWatchingTests {
    @Test
    func `Automatic saving waits for sustained playback and saves only once`() throws {
        var tracker = AutomaticContinueWatching()
        let url = try #require(URL(string: "https://provider.example/movie/1"))

        for second in 0 ... 40 {
            let candidate = tracker.observe(
                url: url, title: "Star Trek Beyond", siteName: "Provider",
                video: playbackVideo(position: Double(second)),
                now: Date(timeIntervalSince1970: Double(second))
            )

            #expect((candidate != nil) == (second == 30))
        }
    }

    @Test
    func `Netflix title is reused only for its matching player ID`() throws {
        var tracker = AutomaticContinueWatching()
        let detail = try #require(URL(string: "https://www.netflix.com/browse?jbv=123"))
        let player = try #require(URL(string: "https://www.netflix.com/watch/123"))

        _ = tracker.observe(url: detail, title: "Star Trek Beyond", siteName: "Netflix", video: nil)

        var saved: PlaybackPageTitle?

        for second in 0 ... 30 {
            saved = tracker.observe(
                url: player, title: "Netflix", siteName: "Netflix",
                video: playbackVideo(position: Double(second)),
                now: Date(timeIntervalSince1970: Double(second))
            )
        }

        #expect(saved?.title == "Star Trek Beyond")
        #expect(saved?.url.absoluteString == "https://www.netflix.com/title/123")

        let other = try #require(URL(string: "https://www.netflix.com/watch/456"))

        for second in 31 ... 65 {
            #expect(tracker.observe(
                url: other, title: "Netflix", siteName: "Netflix",
                video: playbackVideo(position: Double(second)),
                now: Date(timeIntervalSince1970: Double(second))
            ) == nil)
        }
    }

    @Test(arguments: ["short", "buffering", "seeking", "paused", "stalled", "jump"])
    func `Playback interruptions and short videos do not trigger saving`(mode: String) throws {
        let url = try #require(URL(string: "https://provider.example/movie/1"))
        var tracker = AutomaticContinueWatching()

        for second in 0 ... 40 {
            let position = mode == "stalled" ? 0 : Double(second) * (mode == "jump" ? 10 : 1)

            #expect(tracker.observe(
                url: url, title: "A Movie", siteName: "Provider",
                video: playbackVideo(
                    position: position,
                    duration: mode == "short" ? 120 : 7200,
                    paused: mode == "paused",
                    seeking: mode == "seeking",
                    readyState: mode == "buffering" ? 2 : 4
                ),
                now: Date(timeIntervalSince1970: Double(second))
            ) == nil)
        }
    }

    @Test
    func `Captured play link title survives navigation clearing diagnostics`() throws {
        let controller = VideoDiagnosticsController()
        controller.receive(json: """
        {"frameID":"main","videos":[],"pageURL":"https://www.netflix.com/browse",
         "title":"Netflix","linkedURL":"https://www.netflix.com/watch/123","linkedTitle":"Dune: Part Two"}
        """)

        controller.clear()

        let linked = try #require(controller.linkedTitle)
        var tracker = AutomaticContinueWatching()
        tracker.rememberTitle(linked.title, for: linked.url, siteName: "Netflix")

        var saved: PlaybackPageTitle?

        for second in 0 ... 30 {
            saved = tracker.observe(
                url: linked.url, title: "Netflix", siteName: "Netflix",
                video: playbackVideo(position: Double(second)),
                now: Date(timeIntervalSince1970: Double(second))
            )
        }

        #expect(saved?.title == "Dune: Part Two")
    }

    private func playbackVideo(
        position: Double,
        duration: Double = 7200,
        paused: Bool = false,
        seeking: Bool = false,
        readyState: Int = 4
    ) -> VideoDiagnostic {
        VideoDiagnostic(
            id: "playing",
            videoWidth: 1280,
            videoHeight: 720,
            displayWidth: 640,
            displayHeight: 360,
            paused: paused,
            ended: false,
            seeking: seeking,
            readyState: readyState,
            currentTime: position,
            duration: duration,
            bufferedAhead: 10,
            droppedFrames: nil,
            totalFrames: nil,
            sourceDescription: nil,
            sourceType: nil
        )
    }
}
