import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct NetflixContinueWatchingTests {
        @Test
        func `Netflix progress cards use accessible titles and preserve preview links`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.netflix.com/"><title>Netflix</title>
            <div data-virtual-slot="0"><a href="/browse?jbv=80167481" aria-label="How It Ends" data-uia="progress-card">
                <div data-uia="card-image-focus-host"><img alt="" class="continue-watching-card tracked-card"></div>
            </a></div>
            <div data-virtual-slot="1"><a href="/browse?jbv=70281562" aria-label="Brooklyn Nine-Nine"
                data-uia="progress-card"><img alt=""></a></div>
            <a href="/title/999" aria-label="Unrelated recommendation"><img alt="Other Title"></a>
            """], adapter: .netflix)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 2 }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["How It Ends", "Brooklyn Nine-Nine"])
            #expect(fixture.continueWatchingQueue.entries.map(\.id) == ["80167481", "70281562"])
            #expect(fixture.continueWatchingQueue.entries.first?.url.query == "jbv=80167481")
        }

        @Test(arguments: ["fetch", "xhr"])
        func `Netflix GraphQL titles enrich only identified progress cards`(transport: String) async throws {
            let fixture = VideoObserverFixture(pages: ["/browse": """
            <base href="https://www.netflix.com/">
            <a data-uia="progress-card" href="/browse?jbv=81458416"><img alt=""></a>
            <a data-uia="progress-card" href="/browse?jbv=80167481"><img alt=""></a>
            <script>
            if ('\(transport)' === 'fetch') {
                fetch('https://www.netflix.com/graphql').then(r => r.json())
                    .then(data => document.title = data.data.unifiedEntities[0].title);
            } else {
                const request = new XMLHttpRequest();
                request.open('POST', 'https://www.netflix.com/graphql');
                request.addEventListener('load', () => {
                    document.title = JSON.parse(request.responseText).data.unifiedEntities[0].title;
                });
                request.send();
            }
            </script>
            """], pageScript: """
            const payload = {data: {unifiedEntities: [
                {__typename: 'Movie', videoId: 81458416, title: 'Glass Onion',
                 bookmark: {position: 127}, runtimeSec: 8480},
                {__typename: 'Movie', videoId: 80167481, title: 'How It Ends',
                 bookmark: {position: 100}, runtimeSec: 0},
                {__typename: 'Movie', videoId: 123, title: 'Unrelated'}
            ]}};
            globalThis.fetch = async () => new Response(JSON.stringify(payload));
            XMLHttpRequest.prototype.send = function() {
                Object.defineProperties(this, {
                    status: {value: 200}, responseURL: {value: 'https://www.netflix.com/graphql'},
                    responseText: {value: JSON.stringify(payload)}
                });
                this.dispatchEvent(new Event('load'));
            };
            """, adapter: .netflix)
            defer { fixture.stop() }

            try await fixture.load("/browse")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.title == "Glass Onion" }

            #expect(fixture.continueWatchingQueue.entries.first?.progress == 127.0 / 8480.0)
            #expect(fixture.continueWatchingQueue.entries.last?.progress == nil)
            #expect(fixture.continueWatchingQueue.entries.map(\.id) == ["81458416", "80167481"])
            #expect(fixture.continueWatchingQueue.entries.first?.url.query == "jbv=81458416")
        }

        @Test
        func `Netflix progress survives opening and closing a detail overlay`() async throws {
            let fixture = VideoObserverFixture(pages: ["/browse": """
            <base href="https://www.netflix.com/">
            <a data-uia="progress-card" href="/browse?jbv=81458416" aria-label="Glass Onion"></a>
            <a data-uia="progress-card" href="/browse?jbv=2" aria-label="Before"></a>
            <script>fetch('https://www.netflix.com/graphql');</script>
            """], pageScript: """
            globalThis.fetch = async () => new Response(JSON.stringify({data: {unifiedEntities: [
                {videoId: 81458416, title: 'Glass Onion', bookmark: {position: 127}, runtimeSec: 8480}
            ]}}));
            """, adapter: .netflix)
            defer { fixture.stop() }

            try await fixture.load("/browse")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.progress != nil }

            for (path, label) in [("/browse?jbv=81458416", "Open"), ("/browse", "Closed")] {
                _ = try await fixture.webView.evaluateJavaScript("""
                history.pushState({}, '', new URL('\(path)', location.href).href);
                document.querySelectorAll('[data-uia="progress-card"]')[1].setAttribute('aria-label', '\(label)');
                """)
                try await fixture.waitUntil { fixture.continueWatchingQueue.entries.last?.title == label }
                #expect(fixture.continueWatchingQueue.entries.first?.progress == 127.0 / 8480.0)
            }
        }

        @Test
        func `Netflix queue markers on headings still identify the containing shelf`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <title>Netflix</title>
            <div class="lolomoRow"><h2 data-list-context="continueWatching">Continue Watching</h2>
            <div class="title-card"><a href="https://www.netflix.com/title/123">
            <span class="fallback-text">A Show</span></a></div></div>
            """], adapter: .netflix)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "A Show")
            #expect(fixture.continueWatchingQueue.entries.first?.url.path == "/title/123")
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
    }
}

@MainActor
struct NetflixContinueWatchingPersistenceTests {
    @Test
    func `Netflix retains saved progress when a later snapshot omits it`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = JSONFileStore<ContinueWatchingSnapshot?>(
            fileName: "netflix.json", folderName: "queues", baseDirectory: directory
        )
        let url = try #require(URL(string: "https://www.netflix.com/browse"))
        let controller = ContinueWatchingController(adapter: .netflix, fileStore: store)
        controller.receive(json: """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/watch/123","progress":0.4}]
        """, from: url)
        controller.receive(json: """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/watch/123"},
         {"id":"456","title":"Another","url":"https://www.netflix.com/watch/456"}]
        """, from: url)

        let restored = ContinueWatchingController(adapter: .netflix, fileStore: store)
        #expect(restored.entries.map(\.progress) == [0.4, nil])

        restored.receive(json: """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/watch/123","progress":0}]
        """, from: url)
        #expect(restored.entries.first?.progress == 0)

        restored.receive(json: "[]", from: url)
        #expect(restored.entries.isEmpty)
    }
}
