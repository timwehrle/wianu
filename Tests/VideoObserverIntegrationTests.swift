import Foundation
import Testing
import WebKit
@testable import Wianu

@MainActor
struct VideoObserverIntegrationTests {
    @Test
    func `Netflix play click captures the title before navigating to a generic player page`() async throws {
        let fixture = VideoObserverFixture(pages: [
            "/browse": """
            <title>Netflix</title>
            <div class="previewModal--container">
                <img class="title-logo" alt="Dune: Part Two">
                <a href="wianu-test://www.netflix.com/watch/123"><span id="play">Play</span></a>
            </div>
            """,
            "/watch/123": "<title>Netflix</title><video width=640 height=360></video>"
        ])
        defer { fixture.stop() }

        try await fixture.load("/browse")
        try await fixture.waitUntil { fixture.diagnostics.pageTitle == "Dune: Part Two" }

        _ = try await fixture.webView.evaluateJavaScript("document.getElementById('play').click()")

        try await fixture.waitUntil {
            fixture.diagnostics.pageURL?.path == "/watch/123"
                && fixture.diagnostics.pageTitle == "Netflix"
                && fixture.diagnostics.selectedVideo != nil
        }

        #expect(fixture.diagnostics.linkedTitle?.title == "Dune: Part Two")
        #expect(fixture.diagnostics.linkedTitle?.url.path == "/watch/123")
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
        #expect(fixture.diagnostics.linkedTitle == nil)
    }
}

@MainActor
private final class VideoObserverFixture {
    let diagnostics = VideoDiagnosticsController()
    let webView: WKWebView

    private let host: String

    init(pages: [String: String], host: String = "www.netflix.com") {
        self.host = host

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        // Periodic reports must not hide broken playback-event or mutation callbacks.
        configuration.userContentController.addUserScript(WKUserScript(
            source: "globalThis.setInterval = () => 0;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .world(name: "WianuVideoDiagnostics")
        ))
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
        let deadline = ContinuousClock.now + .seconds(5)

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
