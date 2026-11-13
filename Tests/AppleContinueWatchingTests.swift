import Foundation
import Testing
@testable import Wianu

@MainActor
struct AppleContinueWatchingTests {
    private static let card = """
    <section data-testid="shelf-component"><ul data-testid="shelf-item-list"><li>
        <div data-testid="continue-watching-lockup-container">
            <div data-testid="continue-watching-lockup" tabindex="0">
                <img alt="" role="presentation">
                <span class="visually-hidden">Tehran, Emergency Landing in Tehran, S1, E1, 26 min left</span>
                <div class="metadata" aria-hidden="true">S1, E1 · 26m</div>
                <button aria-label="more">More</button>
            </div>
        </div>
    </li></ul></section>
    <a data-testid="lockup" href="https://tv.apple.com/us/show/recommendation/umc.cmc.other">Other Show</a>
    """

    @Test(arguments: ["fetch", "xhr"])
    func `Apple div cards resolve episode titles and URLs from page responses`(transport: String) async throws {
        let fixture = VideoObserverFixture(pages: ["/": Self.card + """
        <script>
        if ("\(transport)" === "fetch") {
            fetch('https://tv.apple.com/api/uts/v3/shelves/uts.col.upnext')
                .then(response => response.json()).then(json => document.title = json.data.items[0].showTitle);
        } else {
            const request = new XMLHttpRequest();
            request.open('GET', 'https://tv.apple.com/api/uts/v3/shelves/uts.col.upnext');
            request.addEventListener('load', () => {
                document.title = JSON.parse(request.responseText).data.items[0].showTitle;
            });
            request.send();
        }
        </script>
        """], host: "tv.apple.com", pageScript: """
        const payload = { data: { items: [{
            id: 'umc.cmc.episode1', type: 'Episode', title: 'Emergency Landing in Tehran', showTitle: 'Tehran',
            url: 'https://tv.apple.com/us/episode/emergency-landing-in-tehran/umc.cmc.episode1',
            playables: { episode: { canonicalMetadata: { showTitle: 'Tehran', seasonNumber: 1, episodeNumber: 1 } } }
        }, {
            id: 'umc.cmc.other', type: 'Show', title: 'Other Show',
            url: 'https://tv.apple.com/us/show/recommendation/umc.cmc.other'
        }] } };
        globalThis.fetch = async () => new Response(JSON.stringify(payload));
        XMLHttpRequest.prototype.send = function() {
            Object.defineProperties(this, {
                status: { value: 200 },
                responseURL: { value: 'https://tv.apple.com/api/uts/v3/shelves/uts.col.upnext' },
                responseText: { value: JSON.stringify(payload) }
            });
            this.dispatchEvent(new Event('load'));
        };
        """, adapter: .appleTV)
        defer { fixture.stop() }

        try await fixture.load("/")
        try await fixture.waitUntil {
            fixture.continueWatchingQueue.updatedAt != nil && fixture.diagnostics.pageTitle == "Tehran"
        }

        let entry = try #require(fixture.continueWatchingQueue.entries.first)
        #expect(fixture.continueWatchingQueue.entries.count == 1)
        #expect(entry.title == "Tehran")
        #expect(entry.episodeTitle == "Emergency Landing in Tehran")
        #expect(entry.season == 1)
        #expect(entry.episode == 1)
        #expect(entry.url.path == "/us/episode/emergency-landing-in-tehran/umc.cmc.episode1")
    }

    @Test
    func `Apple captures serialized card data before hydration removes it`() async throws {
        let fixture = VideoObserverFixture(pages: ["/": """
        <script id="serialized-server-data" type="application/json">
        {"data":[{"$kind":"ContinueWatchingLockup","id":"umc.cmc.episode1","type":"Episode","title":"Tehran",
          "ariaLabel":"Tehran, Emergency Landing in Tehran, S1, E1, 26 min left",
          "segue":{"url":"https://tv.apple.com/us/episode/emergency-landing-in-tehran/umc.cmc.episode1"}}]}
        </script>
        <script type="module">document.getElementById('serialized-server-data').remove();</script>
        \(Self.card)
        """], host: "tv.apple.com", adapter: .appleTV)
        defer { fixture.stop() }

        try await fixture.load("/")
        try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

        #expect(fixture.continueWatchingQueue.entries.first?.title == "Tehran")
        #expect(fixture.continueWatchingQueue.entries.first?.id == "umc.cmc.episode1")
        #expect(try await fixture.webView.evaluateJavaScript(
            "document.getElementById('serialized-server-data') === null"
        ) as? Bool == true)
    }

    @Test(arguments: ["missing", "foreign", "ambiguous"])
    func `Unresolved Apple cards cannot erase the saved queue`(reason: String) async throws {
        let payload: String
        if reason == "missing" {
            payload = "[]"
        } else {
            let host = reason == "foreign" ? "other.example" : "tv.apple.com"
            payload = """
            [{"type":"Episode","id":"umc.cmc.episode1","showTitle":"Tehran","title":"Emergency Landing in Tehran",
              "url":"https://\(host)/us/episode/name/umc.cmc.episode1"},
             {"type":"Episode","id":"umc.cmc.episode2","showTitle":"Tehran","title":"Emergency Landing in Tehran",
              "url":"https://\(host)/us/episode/name/umc.cmc.episode2"}]
            """
        }

        let fixture = VideoObserverFixture(pages: ["/": """
        <script id="serialized-server-data" type="application/json">{"data":\(payload)}</script>
        \(Self.card)
        """], host: "tv.apple.com", adapter: .appleTV)
        defer { fixture.stop() }

        let source = try #require(URL(string: "https://tv.apple.com/"))
        fixture.continueWatchingQueue.receive(json: """
        [{"id":"umc.cmc.saved","title":"Saved Show","url":"https://tv.apple.com/us/show/saved/umc.cmc.saved"}]
        """, from: source)

        try await fixture.load("/")
        try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics != nil }

        #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved Show")
    }
}
