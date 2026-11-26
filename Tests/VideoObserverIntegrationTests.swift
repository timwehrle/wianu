import Foundation
import Testing
import WebKit
@testable import Wianu

/// Groups WebKit tests, with each nested suite limiting its own concurrency.
struct WebKitIntegrationTests {}

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct VideoObserverIntegrationTests {
        @Test(arguments: ["netflix", "primeVideo", "disneyPlus", "appleTV"])
        func `Service adapters extract only their Continue Watching shelf`(name: String) async throws {
            let adapter = try #require(ContinueWatchingAdapter.all.first { $0.id.rawValue == name })
            let markup: String
            let host: String

            switch adapter.id {
            case .netflix:
                host = "www.netflix.com"
                markup = """
                <div data-list-context="continueWatching"><div class="title-card">
                <a href="https://www.netflix.com/watch/123"><img alt="A Show"></a></div></div>
                """
            case .primeVideo:
                host = "www.primevideo.com"
                markup = """
                <div data-testid="continue-watching">
                <a href="https://www.primevideo.com/detail/B00ABC"><img alt="A Show"></a></div>
                """
            case .disneyPlus:
                host = "www.disneyplus.com"
                markup = """
                <div><a data-testid="set-item" data-item-id="episode-123"
                href="https://www.disneyplus.com/play/episode-123">Play</a>
                <a data-testid="cw-set-item-metadata"><div>A Show</div><div>S2:E3 Episode</div></a></div>
                """
            case .appleTV:
                host = "tv.apple.com"
                markup = """
                <script id="serialized-server-data" type="application/json">
                {"data":{"shelves":[{"id":"uts.col.ChannelUpNext.tvs.sbd.4000","items":[{
                  "$kind":"ContinueWatchingLockup","id":"umc.cmc.123","title":"A Show",
                  "segue":{"url":"https://tv.apple.com/episode/name/umc.cmc.123"}
                }]}]}}
                </script>
                """
            case .hboMax:
                Issue.record("HBO uses response capture rather than the DOM adapter")
                return
            }

            let fixture = VideoObserverFixture(
                pages: ["/": "<title>Provider</title>" + markup],
                host: host,
                adapter: adapter
            )
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.count == 1)
            #expect(fixture.continueWatchingQueue.entries.first?.title == "A Show")
            #expect(fixture.continueWatchingQueue.entries.first?.url.scheme == "https")
        }

        @Test
        func `An unfinished shelf is not treated as an empty queue and late cards are detected`() async throws {
            let fixture = VideoObserverFixture(pages: [
                "/": "<title>Netflix</title><div data-list-context='continueWatching'></div>"
            ], adapter: .netflix)
            defer { fixture.stop() }

            try await fixture.load("/")

            #expect(fixture.continueWatchingQueue.updatedAt == nil)

            _ = try await fixture.webView.evaluateJavaScript("""
            document.querySelector('[data-list-context]').innerHTML =
                '<a href="https://www.netflix.com/watch/123"><img alt="A Show"></a>';
            """)

            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.id == "123" }
        }

        @Test(arguments: ["document", "metadata", "player"])
        func `Page title sources and video reports reach Swift`(source: String) async throws {
            let titleMarkup = switch source {
            case "metadata":
                """
                <title>Netflix</title>
                <meta property="og:type" content="video.movie">
                <meta property="og:title" content="Dune: Part Two">
                """
            case "player":
                "<title>Netflix</title><div data-uia='video-title'>Dune: Part Two</div>"
            default:
                "<title>Dune: Part Two</title>"
            }

            let fixture = VideoObserverFixture(pages: [
                "/watch/123": "\(titleMarkup)<video width=640 height=360></video>"
            ])
            defer { fixture.stop() }

            try await fixture.load("/watch/123")
            try await fixture.waitUntil {
                fixture.diagnostics.pageTitle == "Dune: Part Two"
                    && fixture.diagnostics.selectedVideo != nil
            }

            let video = try #require(fixture.diagnostics.selectedVideo)

            #expect(fixture.diagnostics.mediaTitle == (source == "document" ? nil : "Dune: Part Two"))
            #expect(video.paused)
            #expect(video.duration == nil)
            #expect(video.displayWidth == 640)
            #expect(video.displayHeight == 360)
        }

        @Test
        func `Prime player title takes precedence over its marketing metadata`() async throws {
            let fixture = VideoObserverFixture(pages: [
                "/detail/123": """
                <title>Prime Video: Filme, Serien, Sport und Live-TV ansehen</title>
                <meta property="og:title" content="Prime Video: Filme, Serien, Sport und Live-TV ansehen">
                <div class="atvwebplayersdk-title-text">Dune: Part Two</div>
                <video width=640 height=360></video>
                """
            ], host: "www.primevideo.com")
            defer { fixture.stop() }

            try await fixture.load("/detail/123")
            try await fixture.waitUntil {
                fixture.diagnostics.pageTitle == "Dune: Part Two"
                    && fixture.diagnostics.selectedVideo != nil
            }

            #expect(fixture.diagnostics.mediaTitle == "Dune: Part Two")

            _ = try await fixture.webView.evaluateJavaScript("""
            document.querySelector('.atvwebplayersdk-title-text').remove();
            """)

            try await fixture.waitUntil {
                fixture.diagnostics.pageTitle == "Prime Video: Filme, Serien, Sport und Live-TV ansehen"
            }

            #expect(fixture.diagnostics.mediaTitle == nil)
        }

        @Test(arguments: [
            "Prime Video: Filme, Serien, Sport und Live-TV ansehen",
            "Watch movies, shows and sports",
            "Regardez des films et des séries",
            "Any future provider slogan"
        ])
        func `Website titles are not treated as media titles in any language`(title: String) async throws {
            let fixture = VideoObserverFixture(pages: [
                "/detail/123": """
                <title>\(title)</title>
                <meta property="og:type" content="website">
                <meta property="og:title" content="\(title)">
                <video></video>
                """
            ], host: "www.primevideo.com")
            defer { fixture.stop() }

            try await fixture.load("/detail/123")
            try await fixture.waitUntil { fixture.diagnostics.selectedVideo != nil }

            #expect(fixture.diagnostics.pageTitle == title)
            #expect(fixture.diagnostics.mediaTitle == nil)
        }

        @Test
        func `Playback events and DOM mutations produce decodable reports`() async throws {
            let fixture = VideoObserverFixture(pages: [
                "/watch/123": "<title>Netflix</title><video></video>"
            ])
            defer { fixture.stop() }

            try await fixture.load("/watch/123")
            try await fixture.waitUntil { fixture.diagnostics.selectedVideo != nil }

            fixture.diagnostics.clear()

            _ = try await fixture.webView.evaluateJavaScript("""
            document.querySelector('video').dispatchEvent(new Event('playing'));
            """)

            try await fixture.waitUntil { fixture.diagnostics.selectedVideo != nil }

            _ = try await fixture.webView.evaluateJavaScript("document.title = 'Dune: Part Two'")

            try await fixture.waitUntil { fixture.diagnostics.pageTitle == "Dune: Part Two" }
        }

        @Test
        func `Embedded video reports do not replace the main page title`() async throws {
            let fixture = VideoObserverFixture(pages: [
                "/watch/123": """
                <title>Dune: Part Two</title>
                <iframe srcdoc="<title>Embedded player</title><video width=640 height=360></video>"></iframe>
                """
            ])
            defer { fixture.stop() }

            try await fixture.load("/watch/123")
            try await fixture.waitUntil { fixture.diagnostics.selectedVideo != nil }

            #expect(fixture.diagnostics.pageTitle == "Dune: Part Two")
            #expect(fixture.diagnostics.pageURL?.path == "/watch/123")
        }
    }
}

@MainActor
final class VideoObserverFixture {
    let diagnostics = VideoDiagnosticsController()
    let continueWatchingQueue: ContinueWatchingController
    let webView: WKWebView

    private let host: String

    init(
        pages: [String: String],
        host: String = "www.netflix.com",
        pageScript: String? = nil,
        adapter: ContinueWatchingAdapter? = nil
    ) {
        self.host = host
        continueWatchingQueue = ContinueWatchingController(adapter: adapter ?? .hboMax)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        // Periodic reports must not hide broken playback-event or mutation callbacks.
        configuration.userContentController.addUserScript(WKUserScript(
            source: "globalThis.setInterval = () => 0;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .world(name: "WianuVideoDiagnostics")
        ))
        if let pageScript {
            configuration.userContentController.addUserScript(WKUserScript(
                source: pageScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
                in: .page
            ))
        }

        continueWatchingQueue.install(in: configuration.userContentController)
        diagnostics.install(in: configuration.userContentController)
        configuration.setURLSchemeHandler(FixturePages(pages: pages), forURLScheme: "wianu-test")

        webView = WKWebView(frame: .zero, configuration: configuration)
    }

    func load(_ path: String) async throws {
        let url = try #require(URL(string: "wianu-test://\(host)\(path)"))
        webView.load(URLRequest(url: url))

        try await waitUntil { self.diagnostics.pageURL == url }
    }

    func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(20)

        while !condition() {
            guard ContinuousClock.now < deadline else { throw FixtureError.timedOut }

            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func stop() {
        webView.stopLoading()
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.configuration.userContentController.removeAllUserScripts()
    }

    private enum FixtureError: Error {
        case timedOut
    }
}

@MainActor
private final class FixturePages: NSObject, WKURLSchemeHandler {
    private let pages: [String: String]

    init(pages: [String: String]) {
        self.pages = pages
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let html = pages[url.path] else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let data = Data(html.utf8)
        let response = URLResponse(
            url: url,
            mimeType: "text/html",
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
