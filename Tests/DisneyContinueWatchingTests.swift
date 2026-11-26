import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct DisneyContinueWatchingDOMTests {
        @Test(arguments: ["S1:E2 Episode Two", "S 1 : E 2 Episode Two", "s1:e2 Episode Two", "S1:F2 Zweite Folge"])
        func `Disney season and episode metadata reaches the sidebar entry`(label: String) async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.disneyplus.com/"><title>Disney+</title>
            <div><a data-testid="set-item" data-item-id="episode-123"
                aria-label="A Show" href="/play/episode-123">Play</a>
                <a data-testid="cw-set-item-metadata"><div>A Show</div><div id="episode">\(label)</div></a>
            </div>
            """], host: "www.disneyplus.com", adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            let entry = try #require(fixture.continueWatchingQueue.entries.first)
            #expect(entry.title == "A Show")
            #expect(entry.season == 1)
            #expect(entry.episode == 2)

            _ = try await fixture.webView.evaluateJavaScript("""
            document.getElementById('episode').textContent = 'S12:E34 Next Episode';
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.episode == 34 }

            #expect(fixture.continueWatchingQueue.entries.first?.season == 12)
        }

        @Test
        func `Disney German episode labels are read from nested metadata beside rating badges`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.disneyplus.com/"><title>Disney+</title>
            <div data-testid="set-shelf-item" role="group" aria-hidden="false" aria-roledescription="slide">
                <span data-testid="cw-set-item-wrapper">
                    <a data-item-id="ae249b50-fc62-4fad-8ad4-8a34f4d03a65" data-testid="set-item"
                        aria-label=
                        "The Bear: King of the Kitchen Staffel 3 Folge 9 Entschuldigungen Noch 23&nbsp;Minuten"
                        href="/de-de/play/ae249b50-fc62-4fad-8ad4-8a34f4d03a65">
                        <div data-testid="set-item-tile"><img alt="">
                            <progress aria-label="45" max="100" value="45"></progress>
                        </div>
                    </a>
                    <a data-testid="cw-set-item-metadata"
                        href="/de-de/browse/entity-05eb6a8e-90ed-4947-8c0b-e6536cbddd5f">
                        <div>Noch 23&nbsp;Min.</div>
                        <div>The Bear: King of the Kitchen</div>
                        <div>
                            <div data-testid="set-item-rating"><img alt="12" src="data:,"></div>
                            <span>S3:F9 Entschuldigungen</span>
                        </div>
                    </a>
                </span>
            </div>
            """], host: "www.disneyplus.com", adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            let entry = try #require(fixture.continueWatchingQueue.entries.first)
            #expect(entry.title == "The Bear: King of the Kitchen")
            #expect(entry.season == 3)
            #expect(entry.episode == 9)
            #expect(entry.episodeTitle == "S3:F9 Entschuldigungen")
            #expect(entry.url.path == "/de-de/play/ae249b50-fc62-4fad-8ad4-8a34f4d03a65")
        }

        @Test
        func `Disney rating badges cannot become show names`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <title>Disney+</title>
            <div><a data-testid="set-item" data-item-id="episode-123"
                href="https://www.disneyplus.com/play/episode-123">Play</a>
            <a data-testid="cw-set-item-metadata">
                <div>16 min</div><div>The Bear: King of the Kitchen</div>
                <div><img alt="16" src="data:,"></div>
                <div>S1:E2 Episode Two <img alt="12" src="data:,"></div>
            </a></div>
            """], host: "www.disneyplus.com", adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "The Bear: King of the Kitchen")
            #expect(fixture.continueWatchingQueue.entries.first?.episodeTitle?.contains("12") == false)
        }

        @Test
        func `Disney movie titles match accessible play labels despite time and genre metadata`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.disneyplus.com/"><title>Disney+</title>
            <div data-testid="set-shelf-item"><span data-testid="cw-set-item-wrapper">
            <a data-testid="set-item" data-item-id="0de850bd-a343-4dd7-86c4-c008cdaca86f"
                aria-label="Black Swan Noch Noch 1&nbsp;Stunde 36&nbsp;Minuten"
                href="/de-de/play/0de850bd-a343-4dd7-86c4-c008cdaca86f">
                <img alt=""><progress aria-label="11" max="100" value="11"></progress>
            </a>
            <a data-testid="cw-set-item-metadata" href="/de-de/browse/entity-0de850bd-a343-4dd7-86c4-c008cdaca86f">
                <div>Noch 1&nbsp;Std. 36&nbsp;Min.</div><div>Black Swan</div>
                <div><div data-testid="set-item-rating"><img alt="16" src="data:,"></div>
                    <span>2010<span aria-hidden="true">•</span>Drama, Tanz</span></div>
            </a></span></div>
            """], host: "www.disneyplus.com", adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "Black Swan")
            #expect(fixture.continueWatchingQueue.entries.first?.season == nil)
            #expect(fixture.continueWatchingQueue.entries.first?.episode == nil)
            #expect(fixture.continueWatchingQueue.entries.first?.url
                .path == "/de-de/play/0de850bd-a343-4dd7-86c4-c008cdaca86f")
        }

        @Test(arguments: ["Noch 1&nbsp;Std. 40&nbsp;Min.", "1 hr 40 min left", "Il reste 1 h 40 min", "残り1時間40分"])
        func `Disney film badges and localized time labels do not replace titles`(timeLabel: String) async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.disneyplus.com/"><title>Disney+</title>
            <div data-testid="set-shelf-item"><span data-testid="cw-set-item-wrapper">
            <a data-testid="set-item" data-item-id="ddbf02a4-a0c2-48f1-9e1a-5055fe864dec"
                aria-label="Dieses Label weist auf neu hinzugefügte Inhalte hin.
                    Im Rausch der Sterne Noch Noch 1 Stunde"
                href="/de-de/play/ddbf02a4-a0c2-48f1-9e1a-5055fe864dec"><img alt="">
                <span data-testid="badge-slot-2">Neu</span><progress value="3" max="100"></progress></a>
            <a data-testid="cw-set-item-metadata" href="/de-de/browse/entity-ddbf02a4-a0c2-48f1-9e1a-5055fe864dec">
                <div>\(timeLabel)</div><div>Im Rausch der Sterne</div>
                <div><div data-testid="set-item-rating"><img alt="6" src="data:,"></div>
                    <span>2015<span aria-hidden="true">•</span>Drama, Comedy</span></div>
            </a></span></div>
            """], host: "www.disneyplus.com", adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            let entry = try #require(fixture.continueWatchingQueue.entries.first)
            #expect(entry.title == "Im Rausch der Sterne")
            #expect(entry.id == "ddbf02a4-a0c2-48f1-9e1a-5055fe864dec")
            #expect(entry.url.path == "/de-de/play/ddbf02a4-a0c2-48f1-9e1a-5055fe864dec")
        }

        @Test
        func `Disney mixed movie and episode shelves work without accessible play titles`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.disneyplus.com/"><title>Disney+</title>
            <div><a data-testid="set-item" data-item-id="film-one" href="/de-de/play/film-one"><img alt=""></a>
            <a data-testid="cw-set-item-metadata"><div>Noch 1&nbsp;Std. 40&nbsp;Min.</div>
                <div>Im Rausch der Sterne</div><div>2015•Drama, Comedy</div></a></div>
            <div><a data-testid="set-item" data-item-id="film-two" href="/de-de/play/film-two"><img alt=""></a>
            <a data-testid="cw-set-item-metadata"><div>Noch 3&nbsp;Std. 7&nbsp;Min.</div>
                <div>Avatar: The Way of Water</div><div>2022•Action und Abenteuer, Science-Fiction</div></a></div>
            <div><a data-testid="set-item" data-item-id="episode" href="/de-de/play/episode"><img alt=""></a>
            <a data-testid="cw-set-item-metadata"><div>Noch 23&nbsp;Min.</div>
                <div>The Bear: King of the Kitchen</div><div>S3:F9 Entschuldigungen</div></a></div>
            """], host: "www.disneyplus.com", adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == [
                "Im Rausch der Sterne", "Avatar: The Way of Water", "The Bear: King of the Kitchen"
            ])
            #expect(fixture.continueWatchingQueue.entries.map(\.id) == ["film-one", "film-two", "episode"])
            #expect(fixture.continueWatchingQueue.entries.last?.season == 3)
            #expect(fixture.continueWatchingQueue.entries.last?.episode == 9)
        }

        @Test(arguments: ["16 min", "Noch 16 Min.", "Il reste 16 min", "残り16分"])
        func `Disney year and genre descriptions cannot be used as film titles`(timeLabel: String) async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <title>Disney+</title>
            <div><a data-testid="set-item" data-item-id="film-id"
                href="https://www.disneyplus.com/play/film-id">Play</a>
            <a data-testid="cw-set-item-metadata">
                <div>\(timeLabel)</div><div>2010•Drama, Tanz</div><div><img alt="16" src="data:,"></div>
            </a></div>
            """], host: "www.disneyplus.com", adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics != nil }

            #expect(fixture.continueWatchingQueue.entries.isEmpty)
            #expect(fixture.continueWatchingQueue.updatedAt == nil)
            #expect(fixture.continueWatchingQueue.diagnostics?.contains("2010•Drama, Tanz") == true)
            let report = try #require(fixture.continueWatchingQueue.diagnostics?.data(using: .utf8))
            let diagnostics = try #require(JSONSerialization.jsonObject(with: report) as? [String: Any])
            let unreadable = try #require(diagnostics["unreadableCards"] as? [[String: Any]])
            #expect(unreadable.first?["missing"] as? [String] == ["title"])
        }
    }
}

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct DisneyContinueWatchingResponseTests {
        private static let endpoint = "https://disney.api.edge.bamgrid.com/explore/v1.21/set/"
            + "76aed686-1837-49bd-b4f5-5d2a27c0c8d4?setStyle=continue_watching&limit=15"
        private static let payload = """
        {"data":{"set":{"type":"set","id":"76aed686-1837-49bd-b4f5-5d2a27c0c8d4","items":[
          {"type":"view","id":"ddbf02a4-a0c2-48f1-9e1a-5055fe864dec",
           "actions":[{"type":"browse","deeplinkId":"entity-film"},
                      {"type":"playback","deeplinkId":"ddbf02a4-a0c2-48f1-9e1a-5055fe864dec"}],
           "visuals":{"title":"Im Rausch der Sterne","badges":{"slot2":{"brief":"Neu"}}},
           "personalization":{"userState":{"progress":{"progressPercentage":3}}}},
          {"type":"view","id":"ae249b50-fc62-4fad-8ad4-8a34f4d03a65",
           "actions":[{"type":"browse","deeplinkId":"entity-05eb6a8e-90ed-4947-8c0b-e6536cbddd5f"},
                      {"type":"playback","deeplinkId":"ae249b50-fc62-4fad-8ad4-8a34f4d03a65"}],
           "visuals":{"title":"The Bear: King of the Kitchen","episodeTitle":"Entschuldigungen",
                      "seasonNumber":"3","episodeNumber":"9"},
           "personalization":{"userState":{"progress":{"progressPercentage":45}}}}
        ],"pagination":{"hasMore":false,"hasPrev":false,"currentOffset":0,"totalCount":2}}}}
        """

        @Test(arguments: ["fetch", "xhr"])
        func `Disney switches profiles without retaining the previous queue`(transport: String) async throws {
            let profileURL = "https://disney.api.edge.bamgrid.com/v1/public/graphql?op=me"
            let fixture = VideoObserverFixture(
                pages: ["/de-de/home": "<title>Disney+</title>"],
                host: "www.disneyplus.com",
                pageScript: """
                globalThis.activeProfile = '11111111-1111-1111-1111-111111111111';
                globalThis.fetch = async url => new Response(JSON.stringify(
                    String(url).includes('op=me')
                        ? {data: {me: {account: {activeProfile: {id: activeProfile}}}}}
                        : \(Self.payload)
                ));
                XMLHttpRequest.prototype.send = function() {
                    const payload = {data: {me: {account: {activeProfile: {id: activeProfile}}}}};
                    Object.defineProperties(this, {
                        status: {value: 200}, responseURL: {value: '\(profileURL)'},
                        responseText: {value: JSON.stringify(payload)}
                    });
                    this.dispatchEvent(new Event('load'));
                };
                globalThis.loadProfile = () => {
                    if ('\(transport)' === 'fetch') fetch('\(profileURL)');
                    else { const xhr = new XMLHttpRequest(); xhr.open('POST', '\(profileURL)'); xhr.send(); }
                };
                """,
                adapter: .disneyPlus
            )
            defer { fixture.stop() }

            try await fixture.load("/de-de/home")
            try await fixture.webView.evaluateJavaScript("loadProfile(); void 0;")
            try await fixture
                .waitUntil { fixture.continueWatchingQueue.profileID == "11111111-1111-1111-1111-111111111111" }
            try await fixture.webView.evaluateJavaScript("fetch('\(Self.endpoint)'); void 0;")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 2 }

            try await fixture.webView.evaluateJavaScript("""
            activeProfile = '22222222-2222-2222-2222-222222222222'; loadProfile(); void 0;
            """)
            try await fixture
                .waitUntil { fixture.continueWatchingQueue.profileID == "22222222-2222-2222-2222-222222222222" }
            #expect(fixture.continueWatchingQueue.entries.isEmpty)
            try await fixture.webView.evaluateJavaScript("fetch('\(Self.endpoint)'); void 0;")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 2 }
            #expect(fixture.continueWatchingQueue.profileID == "22222222-2222-2222-2222-222222222222")
        }

        @Test(arguments: ["fetch", "xhr", "xhr-json", "dynamic-set"])
        func `Disney responses provide ordered playback entries without HTML parsing`(transport: String) async throws {
            let setID = transport == "dynamic-set" ? "future-set" : "76aed686-1837-49bd-b4f5-5d2a27c0c8d4"
            let endpoint = Self.endpoint.replacingOccurrences(of: "76aed686-1837-49bd-b4f5-5d2a27c0c8d4", with: setID)
            let fixture = VideoObserverFixture(pages: ["/de-de/home": """
            <script>
            if (!'\(transport)'.startsWith('xhr')) {
                fetch('\(endpoint)').then(r => r.json()).then(data => {
                    document.title = data.data.set.items[0].visuals.title;
                });
            } else {
                const request = new XMLHttpRequest();
                request.open('GET', '\(endpoint)');
                if ('\(transport)' === 'xhr-json') request.responseType = 'json';
                request.addEventListener('load', () => {
                    const data = request.responseType === 'json' ? request.response : JSON.parse(request.responseText);
                    document.title = data.data.set.items[0].visuals.title;
                });
                request.send();
            }
            </script>
            """], host: "www.disneyplus.com", pageScript: """
            const payload = \(Self.payload);
            payload.data.set.id = '\(setID)';
            globalThis.fetch = async () => new Response(JSON.stringify(payload));
            XMLHttpRequest.prototype.send = function() {
                Object.defineProperties(this, {
                    status: { value: 200 }, responseURL: { value: '\(endpoint)' },
                    responseText: { value: JSON.stringify(payload) }, response: { value: payload }
                });
                this.dispatchEvent(new Event('load'));
            };
            """, adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/de-de/home")
            try await fixture.waitUntil {
                fixture.continueWatchingQueue.entries.count == 2
                    && fixture.diagnostics.pageTitle == "Im Rausch der Sterne"
            }

            let entries = fixture.continueWatchingQueue.entries
            #expect(entries.map(\.title) == ["Im Rausch der Sterne", "The Bear: King of the Kitchen"])
            #expect(entries.first?.url.path == "/de-de/play/ddbf02a4-a0c2-48f1-9e1a-5055fe864dec")
            #expect(entries.last?.url.path == "/de-de/play/ae249b50-fc62-4fad-8ad4-8a34f4d03a65")
            #expect(entries.last?.episodeTitle == "Entschuldigungen")
            #expect(entries.last?.season == 3)
            #expect(entries.last?.episode == 9)
            #expect(entries.first?.progress == 0.03)
            #expect(entries.last?.progress == 0.45)
            #expect(fixture.continueWatchingQueue.diagnostics?.contains("\"source\": \"response\"") == true)
        }

        @Test(arguments: ["null", "-1", "101", "\"45\""])
        func `Disney ignores missing or invalid progress`(percentage: String) async throws {
            let fixture = VideoObserverFixture(pages: ["/de-de/home": """
            <script>fetch('\(Self.endpoint)');</script>
            """], host: "www.disneyplus.com", pageScript: """
            const payload = \(Self.payload);
            payload.data.set.items[0].personalization.userState.progress.progressPercentage = \(percentage);
            globalThis.fetch = async () => new Response(JSON.stringify(payload));
            """, adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/de-de/home")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 2 }

            #expect(fixture.continueWatchingQueue.entries.first?.progress == nil)
            #expect(fixture.continueWatchingQueue.entries.last?.progress == 0.45)
        }

        @Test(arguments: ["partial", "offset", "count", "title", "set", "host", "style", "status", "json"])
        func `Incomplete or unrelated Disney responses preserve saved entries`(reason: String) async throws {
            var endpoint = Self.endpoint
            if reason == "host" {
                endpoint = endpoint.replacingOccurrences(of: "disney.api.edge.bamgrid.com", with: "other.example")
            } else if reason == "style" {
                endpoint = endpoint.replacingOccurrences(of: "continue_watching", with: "recommendations")
            }
            let fixture = VideoObserverFixture(pages: ["/de-de/home": """
            <script>
            fetch('\(endpoint)').then(r => r.text()).then(() => {
                setTimeout(() => document.title = 'Response processed', 750);
            });
            </script>
            """], host: "www.disneyplus.com", pageScript: """
            const payload = \(Self.payload);
            const set = payload.data.set;
            if ('\(reason)' === 'partial') set.pagination.hasMore = true;
            if ('\(reason)' === 'offset') set.pagination.currentOffset = 15;
            if ('\(reason)' === 'count') set.pagination.totalCount = 10;
            if ('\(reason)' === 'title') delete set.items[0].visuals.title;
            if ('\(reason)' === 'set') set.id = 'recommendations';
            globalThis.fetch = async () => new Response('\(reason)' === 'json' ? '{' : JSON.stringify(payload),
                { status: '\(reason)' === 'status' ? 403 : 200 });
            """, adapter: .disneyPlus)
            defer { fixture.stop() }

            try fixture.continueWatchingQueue.receive(json: """
            [{"id":"saved","title":"Saved Show","url":"https://www.disneyplus.com/play/saved"}]
            """, from: #require(URL(string: "https://www.disneyplus.com/")))
            try await fixture.load("/de-de/home")
            try await fixture.waitUntil { fixture.diagnostics.pageTitle == "Response processed" }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["Saved Show"])
        }

        @Test func `A complete empty Disney response clears saved entries`() async throws {
            let fixture = VideoObserverFixture(pages: ["/de-de/home": """
            <script>fetch('\(Self.endpoint)');</script>
            """], host: "www.disneyplus.com", pageScript: """
            const payload = \(Self.payload);
            payload.data.set.items = [];
            payload.data.set.pagination.totalCount = 0;
            globalThis.fetch = async () => new Response(JSON.stringify(payload));
            """, adapter: .disneyPlus)
            defer { fixture.stop() }

            try fixture.continueWatchingQueue.receive(json: """
            [{"id":"saved","title":"Saved Show","url":"https://www.disneyplus.com/play/saved"}]
            """, from: #require(URL(string: "https://www.disneyplus.com/")))
            try await fixture.load("/de-de/home")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.isEmpty }

            #expect(fixture.continueWatchingQueue.updatedAt != nil)
        }

        @Test func `A late Disney response cannot overwrite a newer request`() async throws {
            let fixture = VideoObserverFixture(pages: ["/de-de/home": """
            <script>
            const older = fetch('\(Self.endpoint)');
            const newer = fetch('\(Self.endpoint)');
            releaseOlder();
            Promise.all([older, newer]).then(() => {
                setTimeout(() => document.title = 'Responses processed', 750);
            });
            </script>
            """], host: "www.disneyplus.com", pageScript: """
            const payload = \(Self.payload);
            let releaseOlder;
            let requests = 0;
            globalThis.fetch = () => {
                if (++requests === 1) return new Promise(resolve => {
                    releaseOlder = () => resolve(new Response(JSON.stringify(payload)));
                });
                const newer = JSON.parse(JSON.stringify(payload));
                newer.data.set.items[0].visuals.title = 'Newer title';
                return Promise.resolve(new Response(JSON.stringify(newer)));
            };
            """, adapter: .disneyPlus)
            defer { fixture.stop() }

            try await fixture.load("/de-de/home")
            try await fixture.waitUntil {
                fixture.diagnostics.pageTitle == "Responses processed" && fixture.continueWatchingQueue.entries
                    .count == 2
            }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "Newer title")
        }

        @Test func `A Disney response from a previous page cannot replace the saved queue`() async throws {
            let fixture = VideoObserverFixture(pages: ["/de-de/home": """
            <script>
            const pending = fetch('\(Self.endpoint)');
            pending.then(() => setTimeout(() => document.title = 'Response processed', 750));
            </script>
            """], host: "www.disneyplus.com", pageScript: """
            const payload = \(Self.payload);
            let releaseResponse;
            globalThis.fetch = () => new Promise(resolve => {
                releaseResponse = () => resolve(new Response(JSON.stringify(payload)));
            });
            """, adapter: .disneyPlus)
            defer { fixture.stop() }

            try fixture.continueWatchingQueue.receive(json: """
            [{"id":"saved","title":"Saved Show","url":"https://www.disneyplus.com/play/saved"}]
            """, from: #require(URL(string: "https://www.disneyplus.com/")))
            try await fixture.load("/de-de/home")
            _ = try await fixture.webView.evaluateJavaScript("location.hash = 'another-page'; releaseResponse();")
            try await fixture.waitUntil { fixture.diagnostics.pageTitle == "Response processed" }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")
        }
    }
}
