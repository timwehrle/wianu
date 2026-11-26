import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct HBOMaxContinueWatchingTests {
        @Test
        func `HBO tracks selected profile and clears the previous queue`() async throws {
            let fixture = VideoObserverFixture(
                pages: ["/": "<title>HBO Max</title>"], host: "www.hbomax.com",
                pageScript: """
                globalThis.selectedProfile = 'profile-one';
                globalThis.fetch = async (url) => new Response(JSON.stringify(
                    url.includes('/users/me')
                        ? { data: { attributes: { selectedProfileId: selectedProfile } } }
                        : { data: { attributes: { alias: 'continue-watching' },
                            relationships: { items: { data: [] } } } }
                ));
                """, adapter: .hboMax
            )
            defer { fixture.stop() }

            try await fixture.load("/")
            _ = try await fixture.webView.evaluateJavaScript("fetch('https://www.hbomax.com/users/me'); void 0;")
            try await fixture.waitUntil { fixture.continueWatchingQueue.profileID == "profile-one" }

            let source = try #require(URL(string: "https://www.hbomax.com/"))
            fixture.continueWatchingQueue.receive(json: """
            {"profileID":"profile-one","partial":false,"entries":[
              {"id":"00000000-0000-0000-0000-000000000001","title":"First"}]}
            """, from: source)
            #expect(fixture.continueWatchingQueue.entries.count == 1)

            _ = try await fixture.webView
                .evaluateJavaScript(
                    "selectedProfile = 'profile-two'; fetch('https://www.hbomax.com/users/me'); void 0;"
                )
            try await fixture.waitUntil { fixture.continueWatchingQueue.profileID == "profile-two" }
            #expect(fixture.continueWatchingQueue.entries.isEmpty)

            _ = try await fixture.webView
                .evaluateJavaScript("fetch('https://www.hbomax.com/cms/collections/home'); void 0;")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }
            #expect(fixture.continueWatchingQueue.profileID == "profile-two")
        }

        @Test(arguments: ["null", "0", "-1", "500"])
        func `HBO leaves progress unknown when duration is missing or invalid`(duration: String) async throws {
            let fixture = VideoObserverFixture(
                pages: ["/": "<title>HBO Max</title>"],
                host: "www.hbomax.com",
                pageScript: """
                globalThis.fetch = async () => new Response(JSON.stringify({
                    data: { attributes: { alias: 'continue-watching' }, relationships: {
                        items: { data: [{ type: 'collectionItem', id: 'one' }] }
                    } },
                    included: [
                        { type: 'collectionItem', id: 'one', relationships: {
                            video: { data: { type: 'video', id: '00000000-0000-0000-0000-000000000001' } }
                        } },
                        { type: 'video', id: '00000000-0000-0000-0000-000000000001', attributes: {
                            name: 'Show', viewingHistory: { position: 1000 }
                        }, relationships: { edit: { data: { type: 'edit', id: 'edit' } } } },
                        { type: 'edit', id: 'edit', attributes: { duration: \(duration) } }
                    ]
                }));
                """,
                adapter: .hboMax
            )
            defer { fixture.stop() }

            try await fixture.load("/")
            _ = try await fixture.webView
                .evaluateJavaScript("fetch('https://www.hbomax.com/cms/collections/home'); void 0;")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.first?.progress == nil)
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

        @Test(arguments: ["fetch", "xhr"])
        func `Provider response capture reaches Swift without consuming the website response`(
            transport: String
        ) async throws {
            let fixture = VideoObserverFixture(pages: [
                "/": """
                <title>Loading</title>
                <script>
                if ("\(transport)" === "fetch") {
                    fetch('https://www.hbomax.com/cms/collections/home').then(response => response.json()).then(json => {
                        document.title = json.data.attributes.alias;
                    });
                } else {
                    const request = new XMLHttpRequest();
                    request.open('GET', 'https://www.hbomax.com/cms/collections/home');
                    request.addEventListener('load', () => {
                        document.title = JSON.parse(request.responseText).data.attributes.alias;
                    });
                    request.send();
                }
                </script>
                """
            ], host: "www.hbomax.com", pageScript: """
            const queuePayload = {
                data: {
                    attributes: { alias: "continue-watching" },
                    relationships: { items: { data: [{ type: "collectionItem", id: "card" }] } }
                },
                included: [
                    { type: "collectionItem", id: "card", relationships: {
                        video: { data: { type: "video", id: "00000000-0000-0000-0000-000000000001" } }
                    } },
                    { type: "video", id: "00000000-0000-0000-0000-000000000001", attributes: {
                        name: "The Next Episode", seasonNumber: 2, episodeNumber: 3,
                        viewingHistory: { position: 882857 }
                    }, relationships: {
                        show: { data: { type: "show", id: "series" } },
                        edit: { data: { type: "edit", id: "edit" } }
                    } },
                    { type: "edit", id: "edit", attributes: { duration: 1056000 } },
                    { type: "show", id: "series", attributes: { name: "A Show" } }
                ]
            };
            globalThis.fetch = async () => new Response(JSON.stringify(queuePayload));
            XMLHttpRequest.prototype.send = function() {
                Object.defineProperties(this, {
                    status: { value: 200 },
                    responseURL: { value: 'https://api.hbomax.com/cms/collections/home' },
                    responseText: { value: JSON.stringify(queuePayload) }
                });
                this.dispatchEvent(new Event('load'));
            };
            """)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil {
                fixture.continueWatchingQueue.updatedAt != nil && fixture.diagnostics.pageTitle == "continue-watching"
            }

            #expect(fixture.continueWatchingQueue.entries.first?.title == "A Show")
            #expect(fixture.continueWatchingQueue.entries.first?.episodeTitle == "The Next Episode")
            #expect(fixture.continueWatchingQueue.entries.first?.season == 2)
            #expect(fixture.continueWatchingQueue.entries.first?.episode == 3)
            #expect(fixture.continueWatchingQueue.entries.first?.progress == 882_857.0 / 1_056_000.0)
        }
    }
}
