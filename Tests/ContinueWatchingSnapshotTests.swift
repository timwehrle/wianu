import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    @MainActor
    struct ContinueWatchingSnapshotTests {
        @Test(arguments: ["netflix", "disneyPlus", "primeVideo", "appleTV"])
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

        @Test(arguments: ["netflix", "disneyPlus", "primeVideo", "appleTV"])
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

        @Test(arguments: ["netflix", "disneyPlus", "primeVideo", "appleTV"])
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
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")

            _ = try await fixture.webView.evaluateJavaScript("document.getElementById('queue').remove();")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.isEmpty }
        }

        @Test(arguments: ["netflix", "disneyPlus", "primeVideo", "appleTV"])
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
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")
        }

        @Test
        func `An unreadable card preserves the complete queue until its title loads`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.netflix.com/"><title>Netflix</title>
            <a data-uia="progress-card" href="/browse?jbv=123" aria-label="First Show"></a>
            <a data-uia="progress-card" id="second" href="/browse?jbv=456" aria-label="Second Show"></a>
            """], adapter: .netflix)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 2 }

            _ = try await fixture.webView.evaluateJavaScript("""
            document.getElementById('second').removeAttribute('aria-label');
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("missing") == true }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["First Show", "Second Show"])

            _ = try await fixture.webView.evaluateJavaScript("""
            document.getElementById('second').setAttribute('aria-label', 'Updated Show');
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.last?.title == "Updated Show" }

            #expect(fixture.continueWatchingQueue.entries.count == 2)
        }

        @Test
        func `HBO clears a confirmed empty collection even without included resources`() async throws {
            let fixture = VideoObserverFixture(
                pages: ["/": "<title>HBO Max</title>"],
                host: "www.hbomax.com",
                pageScript: """
                globalThis.fetch = async () => new Response(JSON.stringify({
                    data: {
                        attributes: { alias: 'continue-watching' },
                        relationships: { items: { data: [] } }
                    }
                }));
                """,
                adapter: .hboMax
            )
            defer { fixture.stop() }

            let source = try #require(URL(string: "https://www.hbomax.com/"))
            fixture.continueWatchingQueue.receive(json: """
            [{"id":"00000000-0000-0000-0000-000000000001","title":"Saved Show"}]
            """, from: source)

            try await fixture.load("/")
            _ = try await fixture.webView.evaluateJavaScript("""
            fetch('https://www.hbomax.com/cms/collections/home'); void 0;
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.isEmpty }

            #expect(fixture.continueWatchingQueue.updatedAt != nil)
            #expect(!fixture.continueWatchingQueue.responseError)
        }

        @Test
        func `HBO preserves the complete queue when a referenced video is missing`() async throws {
            let fixture = VideoObserverFixture(
                pages: ["/": "<title>HBO Max</title>"],
                host: "www.hbomax.com",
                pageScript: """
                globalThis.fetch = async () => new Response(JSON.stringify({
                    data: {
                        attributes: { alias: 'continue-watching' },
                        relationships: { items: { data: [
                            { type: 'collectionItem', id: 'one' }, { type: 'collectionItem', id: 'two' }
                        ] } }
                    },
                    included: [
                        { type: 'collectionItem', id: 'one', relationships: {
                            video: { data: { type: 'video', id: '00000000-0000-0000-0000-000000000001' } }
                        } },
                        { type: 'video', id: '00000000-0000-0000-0000-000000000001',
                          attributes: { name: 'First Show' } }
                    ]
                }));
                """,
                adapter: .hboMax
            )
            defer { fixture.stop() }

            let source = try #require(URL(string: "https://www.hbomax.com/"))
            fixture.continueWatchingQueue.receive(json: """
            [{"id":"00000000-0000-0000-0000-000000000001","title":"First Show"},
             {"id":"00000000-0000-0000-0000-000000000002","title":"Second Show"}]
            """, from: source)

            try await fixture.load("/")
            _ = try await fixture.webView.evaluateJavaScript("""
            fetch('https://www.hbomax.com/cms/collections/home')
                .then(response => response.json()).then(() => document.title = 'Response read');
            void 0;
            """)
            try await fixture.waitUntil { fixture.diagnostics.pageTitle == "Response read" }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["First Show", "Second Show"])
        }

        @Test
        func `Signing out of Apple TV preserves the cached queue`() async throws {
            let fixture = try makeHomeFixture(service: "appleTV", path: "/de")
            defer { fixture.stop() }

            try await fixture.load("/de")
            _ = try await fixture.webView.evaluateJavaScript("""
            document.querySelector('[data-testid="account-menu"]').remove();
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")
        }

        private func homePath(for service: String) throws -> String {
            try #require([
                "netflix": "/browse", "disneyPlus": "/de-de/home",
                "primeVideo": "/region/eu", "appleTV": "/de"
            ][service])
        }

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
    }
}
