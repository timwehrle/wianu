import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct PrimeContinueWatchingDOMTests {
        @Test
        func `Prime hydration includes shows without a progress bar`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.primevideo.com/"><title>Prime Video</title>
            <script id="dv-web-page-hydration-data" type="application/json">
            {"page":{"rows":[{"isContinueWatching":false,"entities":[]},
            {"isContinueWatching":true,"estimatedTotal":2,"entities":[
                {"displayTitle":"A Film","link":{"url":"/detail/FILM123"},"progress":{"percentage":25}},
                {"displayTitle":"A Show","link":{"url":"/detail/SHOW456"},
                 "entitlementCues":{"focusMessage":{"icon":"OFFER_ICON"}}}
            ]}]}}
            </script>
            <article data-card-title="Recommendation"><a href="/detail/OTHER789">Other</a>
                <span data-testid="progress-bar" aria-valuenow="30" aria-valuemax="100"></span>
            </article>
            """], host: "www.primevideo.com", adapter: .primeVideo)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 2 }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["A Film", "A Show"])
            #expect(fixture.continueWatchingQueue.entries.first?.progress == 0.25)
            #expect(fixture.continueWatchingQueue.entries.last?.storeOffer == true)
        }

        @Test
        func `Incomplete Prime hydration preserves the saved queue`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.primevideo.com/"><title>Prime Video</title>
            <script id="dv-web-page-hydration-data" type="application/json">
            {"isContinueWatching":true,"estimatedTotal":2,"entities":[
                {"displayTitle":"A Film","link":{"url":"/detail/FILM123"}}
            ]}
            </script>
            """], host: "www.primevideo.com", adapter: .primeVideo)
            defer { fixture.stop() }

            try fixture.continueWatchingQueue.receive(json: """
            [{"id":"SAVED","title":"Saved Show","url":"https://www.primevideo.com/detail/SAVED"}]
            """, from: #require(URL(string: "https://www.primevideo.com/")))

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics?.contains("No readable") == true }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["Saved Show"])
        }

        @Test
        func `Prime reads all cards in the identified Continue Watching shelf`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.primevideo.com/"><title>Prime Video</title>
            <ul data-testid="continue-watching">
                <li><article data-card-title="A Film" data-card-entity-type="Movie">
                    <a href="/detail/FILM123">A Film</a>
                    <span data-testid="progress-bar" aria-valuenow="10" aria-valuemax="100"></span>
                </article></li>
                <li><article data-card-title="A Show" data-card-entity-type="TV Show">
                    <a href="/detail/SHOW456">A Show</a>
                    <div data-testid="card-overlay"><svg><title>Store Filled</title></svg></div>
                </article></li>
            </ul>
            <ul data-testid="card-container-list"><li><article data-card-title="Other Show"
                data-card-entity-type="TV Show"><a href="/detail/OTHER789">Other Show</a>
                <span data-testid="progress-bar" aria-valuenow="20" aria-valuemax="100"></span>
            </article></li></ul>
            """], host: "www.primevideo.com", adapter: .primeVideo)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.count == 2 }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["A Film", "A Show"])
            #expect(fixture.continueWatchingQueue.entries.map(\.storeOffer) == [false, true])
            #expect(fixture.continueWatchingQueue.entries.first?.progress == 0.1)
            #expect(fixture.continueWatchingQueue.entries.last?.progress == nil)

            _ = try await fixture.webView.evaluateJavaScript("""
            document.querySelector('[data-testid="progress-bar"]').setAttribute('aria-valuenow', '50');
            """)
            try await fixture.waitUntil { fixture.continueWatchingQueue.entries.first?.progress == 0.5 }
        }

        @Test
        func `Prime does not treat a progress bar as proof that other carousel cards are in the queue`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.primevideo.com/"><title>Prime Video</title>
            <ul data-testid="card-container-list">
                <li><article data-card-title="In Progress"><a href="/detail/FILM123">Film</a>
                    <span data-testid="progress-bar" aria-valuenow="10" aria-valuemax="100"></span>
                </article></li>
                <li><article data-card-title="Recommendation" data-card-entity-type="TV Show">
                    <a href="/detail/SHOW456">Show</a>
                </article></li>
            </ul>
            """], host: "www.primevideo.com", adapter: .primeVideo)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.map(\.title) == ["In Progress"])
        }

        @Test
        func `Prime reads card titles with regional links and excludes completed or unstarted cards`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://www.primevideo.com/"><title>Prime Video</title>
            <li data-index="1"><article data-testid="card"
                data-card-title="Die Tribute von Panem - Mockingjay Teil 2 [dt./OV]"
                data-card-entity-type="Movie" data-card-entitlement="Unentitled">
                <section data-testid="card-section"><div data-testid="packshot">
                <button aria-label="Die Tribute von Panem - Mockingjay Teil 2 [dt./OV]"></button>
                <a href="/region/eu/detail/0P6FK4CRBD8X30BLGP7SISRBBX?ref_=atv_hm_hom_c_pEHQ18_2_1">Film</a>
                <img alt=""><span data-testid="metadata-badge" aria-label="ANGEBOT">ANGEBOT</span>
                <div data-testid="card-overlay"><span data-testid="progress-bar"
                    aria-valuemin="0" aria-valuemax="100" aria-valuenow="14.279717611142912"></span></div>
                </div></section>
            </article></li>
            <article data-card-title="Completed"><a href="/detail/COMPLETED">Film</a>
                <span data-testid="progress-bar" aria-valuemax="100" aria-valuenow="100"></span></article>
            <article data-card-title="Unstarted"><a href="/detail/UNSTARTED">Film</a>
                <span data-testid="progress-bar" aria-valuemax="100" aria-valuenow="0"></span></article>
            <article data-card-title="Recommendation"><a href="/detail/RECOMMENDATION">Film</a></article>
            """], host: "www.primevideo.com", adapter: .primeVideo)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }

            #expect(fixture.continueWatchingQueue.entries.count == 1)
            #expect(fixture.continueWatchingQueue.entries.first?
                .title == "Die Tribute von Panem - Mockingjay Teil 2 [dt./OV]")
            #expect(fixture.continueWatchingQueue.entries.first?.url
                .path == "/region/eu/detail/0P6FK4CRBD8X30BLGP7SISRBBX")
        }

        @Test
        func `Missing shelves provide structural diagnostics without page query strings`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <title>Prime</title><section data-testid="different-carousel"><h2>Continue Watching</h2></section>
            """], host: "www.primevideo.com", adapter: .primeVideo)
            defer { fixture.stop() }

            try await fixture.load("/?token=secret")
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics != nil }

            let report = try #require(fixture.continueWatchingQueue.diagnostics)

            #expect(report.contains("different-carousel"))
            #expect(!report.contains("secret"))
            #expect(fixture.continueWatchingQueue.updatedAt == nil)
        }
    }
}
