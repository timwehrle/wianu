import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    enum ContinueWatchingSnapshotTests {
        @Suite(.serialized)
        @MainActor
        struct LoadingTests {
            @Test(arguments: ["disneyPlus", "primeVideo"])
            func `Loading home pages preserve saved entries until loading finishes`(service: String) async throws {
                let path = try homePath(for: service)
                let fixture = try makeHomeFixture(
                    service: service, path: path, extraHTML: "<div id='loading' aria-busy='true'></div>"
                )
                defer { fixture.stop() }

                try await fixture.load(path)
                try await fixture
                    .waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("finish loading") == true }

                #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")

                _ = try await fixture.webView.evaluateJavaScript("""
                document.getElementById('loading').setAttribute('aria-busy', 'false');
                """)
                try await fixture.waitUntil { fixture.continueWatchingQueue.entries.isEmpty }
            }

            @Test(arguments: ["disneyPlus", "primeVideo"])
            func `A loaded home page without a Continue Watching section clears saved entries`(
                service: String
            ) async throws {
                let path = try homePath(for: service)
                let fixture = try makeHomeFixture(service: service, path: path)
                defer { fixture.stop() }

                try await fixture.load(path)
                try await fixture.waitUntil { fixture.continueWatchingQueue.entries.isEmpty }

                #expect(fixture.continueWatchingQueue.updatedAt != nil)
                #expect(!fixture.continueWatchingQueue.responseError)
            }
        }

        @Suite(.serialized)
        @MainActor
        struct NavigationTests {
            @Test(arguments: ["disneyPlus", "primeVideo"])
            func `A section placeholder preserves entries until the section disappears`(service: String) async throws {
                let path = try homePath(for: service)
                let placeholder = try #require([
                    "netflix": "<div id='queue' data-list-context='continueWatching'></div>",
                    "disneyPlus": "<section id='queue' data-set-style='continue_watching'></section>",
                    "primeVideo": "<section id='queue' data-testid='continue-watching'></section>",
                    "appleTV": "<div id='queue' data-testid='continue-watching-lockup-container'></div>"
                ][service])
                let fixture = try makeHomeFixture(service: service, path: path, extraHTML: placeholder)
                defer { fixture.stop() }

                try await fixture.load(path)
                try await fixture
                    .waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }

                #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")

                _ = try await fixture.webView.evaluateJavaScript("document.getElementById('queue').remove();")
                try await fixture.waitUntil { fixture.continueWatchingQueue.entries.isEmpty }
            }

            @Test(arguments: ["disneyPlus", "primeVideo"])
            func `Navigating away cancels the pending empty section check`(service: String) async throws {
                let path = try homePath(for: service)
                let fixture = try makeHomeFixture(service: service, path: path)
                defer { fixture.stop() }

                try await fixture.load(path)
                try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("confirm") == true }

                _ = try await fixture.webView.evaluateJavaScript("""
                history.pushState({}, '', new URL('/login', location.href).href);
                document.title = 'Sign In';
                """)
                try await fixture
                    .waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }

                #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")
            }

            @Test
            func `Signing out of Apple TV preserves the cached queue`() async throws {
                let fixture = try makeHomeFixture(service: "appleTV", path: "/de")
                defer { fixture.stop() }

                try await fixture.load("/de")
                _ = try await fixture.webView.evaluateJavaScript("""
                document.querySelector('[data-testid="account-menu"]').remove();
                """)
                try await fixture
                    .waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }

                #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")
            }
        }
    }
}

@MainActor
private func homePath(for service: String) throws -> String {
    try #require([
        "netflix": "/browse", "disneyPlus": "/de-de/home",
        "primeVideo": "/region/eu", "appleTV": "/de"
    ][service])
}

@MainActor
private func makeHomeFixture(
    service: String,
    path: String,
    extraHTML: String = ""
) throws -> VideoObserverFixture {
    let adapter = try #require(ContinueWatchingAdapter.all.first { $0.id.rawValue == service })
    let host = try #require(adapter.hosts.first)
    let source = try #require(URL(string: "https://\(host)/"))
    let recommendation = try #require([
        "netflix": "<a href='/title/999'>Another Show</a>",
        "disneyPlus": "<a data-testid='set-item' data-item-id='999' href='/de-de/browse/entity-999'>"
            + "Another Show</a>",
        "primeVideo": "<article data-card-title='Another Show'>"
            + "<a href='/detail/999'>Another Show</a></article>",
        "appleTV": "<div data-testid='account-menu'></div>"
            + "<a data-testid='lockup' href='/de/show/another/umc.cmc.other'>Another Show</a>"
    ][service])

    let fixture = VideoObserverFixture(pages: [path: """
    <base href="https://\(host)/"><title>Home</title>
    <main>\(recommendation)\(extraHTML)</main>
    """], host: host, adapter: adapter)
    let savedID = service == "appleTV" ? "umc.cmc.saved" : "123"
    let savedPath = try #require([
        "netflix": "/watch/123", "disneyPlus": "/play/123",
        "primeVideo": "/detail/123", "appleTV": "/de/episode/saved/umc.cmc.saved"
    ][service])

    fixture.continueWatchingQueue.receive(json: """
    [{"id":"\(savedID)","title":"Saved Show","url":"https://\(host)\(savedPath)"}]
    """, from: source)

    return fixture
}
