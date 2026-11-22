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
            <a data-uia="progress-card" href="/browse?jbv=80190982"><img alt=""></a>
            <a data-uia="progress-card" href="/browse?jbv=123" aria-label="Original"></a>
            <script>
            const body = JSON.stringify({operationName: 'MiniModalQuery', variables: {
                unifiedEntityIds: ['Video:81458416', 'Video:80167481', 'Video:80190982']
            }});
            if ('\(transport)' === 'fetch') {
                fetch('https://www.netflix.com/graphql', {method: 'POST', body}).then(r => r.json())
                    .then(data => document.title = data.data.unifiedEntities[0].title);
            } else {
                const request = new XMLHttpRequest();
                request.open('POST', 'https://www.netflix.com/graphql');
                request.addEventListener('load', () => {
                    document.title = JSON.parse(request.responseText).data.unifiedEntities[0].title;
                });
                request.send(body);
            }
            </script>
            """], pageScript: """
            const payload = {data: {unifiedEntities: [
                {__typename: 'Movie', videoId: 81458416, title: 'Glass Onion',
                 bookmark: {position: {source: '127.0', parsedValue: 127}}, runtimeSec: 8480},
                {__typename: 'Movie', videoId: 80167481, title: 'How It Ends',
                 bookmark: {position: 100}, runtimeSec: 0},
                {__typename: 'Show', videoId: 80190982, title: "The Handmaid's Tale",
                 currentEpisode: {title: 'Folge 1', number: 1, parentSeason: {number: 1},
                     bookmark: {position: {source: '332.0', parsedValue: 332}}, runtimeSec: 3441}},
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
            #expect(fixture.continueWatchingQueue.entries[1].progress == nil)
            #expect(fixture.continueWatchingQueue.entries[2].progress == 332.0 / 3441.0)
            #expect(fixture.continueWatchingQueue.entries[2].season == 1)
            #expect(fixture.continueWatchingQueue.entries[2].episode == 1)
            #expect(fixture.continueWatchingQueue.entries[2].episodeTitle == "Folge 1")
            #expect(fixture.continueWatchingQueue.entries.map(\.id) == ["81458416", "80167481", "80190982", "123"])
            #expect(fixture.continueWatchingQueue.entries.last?.title == "Original")
            #expect(fixture.continueWatchingQueue.entries.first?.url.query == "jbv=81458416")
        }

        @Test(arguments: ["fetch", "xhr"])
        func `Netflix ignores other GraphQL operations`(transport: String) async throws {
            let fixture = VideoObserverFixture(pages: ["/browse": """
            <base href="https://www.netflix.com/">
            <a data-uia="progress-card" href="/browse?jbv=123" aria-label="Original"></a>
            <script>
            const body = JSON.stringify({operationName: 'OtherQuery', variables: {unifiedEntityIds: ['Video:123']}});
            if ('\(transport)' === 'fetch') {
                fetch('https://www.netflix.com/graphql', {method: 'POST', body})
                    .then(r => r.json()).then(() => document.title = 'Response consumed');
            } else {
                const request = new XMLHttpRequest();
                request.open('POST', 'https://www.netflix.com/graphql');
                request.addEventListener('load', () => document.title = 'Response consumed');
                request.send(body);
            }
            </script>
            """], pageScript: """
            const payload = {data: {unifiedEntities: [
                {videoId: 123, title: 'Wrong', bookmark: {position: 50}, runtimeSec: 100}
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
            try await fixture.waitUntil {
                fixture.diagnostics.pageTitle == "Response consumed" && fixture.continueWatchingQueue.updatedAt != nil
            }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "Original")
            #expect(fixture.continueWatchingQueue.entries.first?.progress == nil)
        }

        @Test
        func `Netflix progress survives opening and closing a detail overlay`() async throws {
            let fixture = VideoObserverFixture(pages: ["/browse": """
            <base href="https://www.netflix.com/">
            <a data-uia="progress-card" href="/browse?jbv=81458416" aria-label="Glass Onion"></a>
            <a data-uia="progress-card" href="/browse?jbv=2" aria-label="Before"></a>
            <script>fetch('https://www.netflix.com/graphql', {method: 'POST', body: JSON.stringify({
                operationName: 'MiniModalQuery', variables: {unifiedEntityIds: ['Video:81458416']}
            })});</script>
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
        func `Netflix episode details survive navigating away and returning home`() async throws {
            let fixture = VideoObserverFixture(pages: ["/browse": """
            <base href="https://www.netflix.com/">
            <a data-uia="progress-card" href="/browse?jbv=123" aria-label="A Show"></a>
            <script>fetch('https://www.netflix.com/graphql', {method: 'POST', body: JSON.stringify({
                operationName: 'MiniModalQuery', variables: {unifiedEntityIds: ['Video:123']}
            })});</script>
            """, "/shows": "<title>Shows</title>"], pageScript: """
            globalThis.fetch = async () => new Response(JSON.stringify({data: {unifiedEntities: [
                {__typename: 'Show', videoId: 123, title: 'A Show', currentEpisode: {
                    videoId: 456, title: 'First', number: 1, parentSeason: {number: 1},
                    bookmark: {position: 50}, runtimeSec: 100
                }}
            ]}}));
            """, adapter: .netflix)
            defer { fixture.stop() }

            try await fixture.load("/browse")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.episode == 1 }
            try await fixture.load("/shows")
            _ = try await fixture.webView.evaluateJavaScript("""
            history.pushState({}, '', new URL('/browse', location.href).href);
            document.body.innerHTML = '<a data-uia="progress-card" '
                + 'href="https://www.netflix.com/title/123" aria-label="A Show"></a>';
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.url.path == "/title/123" }

            #expect(fixture.continueWatchingQueue.entries.first?.season == 1)
            #expect(fixture.continueWatchingQueue.entries.first?.episode == 1)
            #expect(fixture.continueWatchingQueue.entries.first?.episodeTitle == "First")
            #expect(fixture.continueWatchingQueue.entries.first?.progress == 0.5)
        }

        @Test(arguments: ["83", "34399"])
        func `Filtered Netflix shelves update entries without removing other titles`(context: String) async throws {
            let fixture = VideoObserverFixture(pages: ["/browse/genre/\(context)": """
            <base href="https://www.netflix.com/">
            <a data-uia="progress-card" href="/title/123" aria-label="A Show"></a>
            <script>fetch('https://www.netflix.com/graphql', {method: 'POST', body: JSON.stringify({
                operationName: 'MiniModalQuery', variables: {
                    artworkContext: {imageCongruenceContext: '\(context)'}, unifiedEntityIds: ['Video:123']
                }
            })});</script>
            """], pageScript: """
            globalThis.fetch = async () => new Response(JSON.stringify({data: {unifiedEntities: [
                {__typename: 'Movie', videoId: 123, title: 'Updated', bookmark: {position: 50}, runtimeSec: 100}
            ]}}));
            """, adapter: .netflix)
            defer { fixture.stop() }

            let source = try #require(URL(string: "https://www.netflix.com/browse"))
            fixture.continueWatchingQueue.receive(json: """
            [{"id":"123","title":"A Show","url":"https://www.netflix.com/title/123"},
             {"id":"456","title":"A Film","url":"https://www.netflix.com/title/456"}]
            """, from: source)

            try await fixture.load("/browse/genre/\(context)")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.progress == 0.5 }

            #expect(fixture.continueWatchingQueue.entries.map(\.id) == ["123", "456"])
            #expect(fixture.continueWatchingQueue.entries.first?.title == "Updated")
        }

        @Test
        func `Netflix retains entries and order as carousel cards rotate`() async throws {
            let fixture = VideoObserverFixture(pages: ["/browse": """
            <base href="https://www.netflix.com/">
            <div id="carousel">
                <a data-uia="progress-card" href="/title/123" aria-label="First"></a>
                <a data-uia="progress-card" href="/title/456" aria-label="Second"></a>
            </div>
            <a href="/title/555">Recommendation</a>
            <script>fetch('https://www.netflix.com/graphql', {method: 'POST', body: JSON.stringify({
                operationName: 'MiniModalQuery', variables: {
                    artworkContext: {}, unifiedEntityIds: ['Video:123', 'Video:456']
                }
            })});</script>
            """], pageScript: """
            globalThis.fetch = async () => new Response(JSON.stringify({data: {unifiedEntities: [
                {__typename: 'Movie', videoId: 123, title: 'First'},
                {__typename: 'Movie', videoId: 456, title: 'Second'}
            ]}}));
            """, adapter: .netflix)
            defer { fixture.stop() }

            let source = try #require(URL(string: "https://www.netflix.com/browse"))
            fixture.continueWatchingQueue.receive(json: """
            [{"id":"123","title":"First","url":"https://www.netflix.com/title/123"},
             {"id":"456","title":"Second","url":"https://www.netflix.com/title/456"},
             {"id":"789","title":"Third","url":"https://www.netflix.com/title/789"}]
            """, from: source)

            try await fixture.load("/browse")
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("2 readable") == true }
            #expect(fixture.continueWatchingQueue.entries.map(\.id) == ["123", "456", "789"])

            _ = try await fixture.webView.evaluateJavaScript("""
            document.getElementById('carousel').innerHTML = `
                <a data-uia="progress-card" href="/title/789" aria-label="Updated Third"></a>
                <a data-uia="progress-card" href="/title/456" aria-label="Second"></a>
                <a data-uia="progress-card" href="/title/999" aria-label="New"></a>`;
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 4 }

            #expect(fixture.continueWatchingQueue.entries.map(\.id) == ["123", "456", "789", "999"])
            #expect(fixture.continueWatchingQueue.entries[2].title == "Updated Third")

            _ = try await fixture.webView.evaluateJavaScript("document.getElementById('carousel').remove();")
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }
            #expect(fixture.continueWatchingQueue.entries.count == 4)
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
    func `Netflix retains episode details across snapshots and replaces them for a new episode`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = JSONFileStore<ContinueWatchingSnapshot?>(
            fileName: "netflix.json", folderName: "queues", baseDirectory: directory
        )
        let url = try #require(URL(string: "https://www.netflix.com/browse"))
        let controller = ContinueWatchingController(adapter: .netflix, fileStore: store)
        controller.receive(json: """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/title/123",
          "episodeMetadataKnown":true,"season":1,"episode":1,"episodeTitle":"First","progress":0.4}]
        """, from: url)
        controller.receive(json: """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/title/123","episodeMetadataKnown":false}]
        """, from: url)

        let restored = ContinueWatchingController(adapter: .netflix, fileStore: store)
        #expect(restored.entries.first?.season == 1)
        #expect(restored.entries.first?.episode == 1)
        #expect(restored.entries.first?.episodeTitle == "First")
        #expect(restored.entries.first?.progress == 0.4)

        restored.receive(json: """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/title/123",
          "episodeMetadataKnown":true,"season":1,"episode":2,"episodeTitle":"Second"}]
        """, from: url)
        #expect(restored.entries.first?.episode == 2)
        #expect(restored.entries.first?.episodeTitle == "Second")
        #expect(restored.entries.first?.progress == nil)

        restored.receive(json: """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/title/123",
          "episodeMetadataKnown":true}]
        """, from: url)
        #expect(restored.entries.first?.season == nil)
        #expect(restored.entries.first?.episode == nil)
        #expect(restored.entries.first?.episodeTitle == nil)
    }

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
