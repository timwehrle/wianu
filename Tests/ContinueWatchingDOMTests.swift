import Foundation
import Testing
@testable import Wianu

@MainActor
struct ContinueWatchingDOMTests {
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
                    aria-label="The Bear: King of the Kitchen Staffel 3 Folge 9 Entschuldigungen Noch 23&nbsp;Minuten"
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
    func `Apple diagnostics include shelf cards without treating recommendations as a queue`() async throws {
        let fixture = VideoObserverFixture(pages: ["/": """
        <base href="https://tv.apple.com/"><title>Apple TV</title>
        <div data-testid="section-container" id="shelf-one"><div data-testid="section-content">
            <div class="rich-lockup-shelf-header"><div class="header"><div class="header-title-wrapper">
                <h2 data-testid="header-title">Continue Watching on Apple TV</h2>
            </div></div></div>
            <a data-testid="lockup" class="lockup" aria-label="A Show"
                href="/us/episode/episode-one/umc.cmc.example?token=secret"><img alt="A Show"></a>
        </div></div>
        """], host: "tv.apple.com", adapter: .appleTV)
        defer { fixture.stop() }

        try await fixture.load("/")
        try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics != nil }

        let report = try #require(fixture.continueWatchingQueue.diagnostics)
        #expect(report.contains("shelf-one"))
        #expect(report.contains("umc.cmc.example"))
        #expect(report.contains("A Show"))
        #expect(!report.contains("secret"))
        #expect(fixture.continueWatchingQueue.updatedAt == nil)
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
        #expect(fixture.continueWatchingQueue.entries.first?.url.path == "/region/eu/detail/0P6FK4CRBD8X30BLGP7SISRBBX")
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

    @Test
    func `Disney year and genre descriptions cannot be used as film titles`() async throws {
        let fixture = VideoObserverFixture(pages: ["/": """
        <title>Disney+</title>
        <div><a data-testid="set-item" data-item-id="film-id"
            href="https://www.disneyplus.com/play/film-id">Play</a>
        <a data-testid="cw-set-item-metadata">
            <div>16 min</div><div>2010•Drama, Tanz</div><div><img alt="16" src="data:,"></div>
        </a></div>
        """], host: "www.disneyplus.com", adapter: .disneyPlus)
        defer { fixture.stop() }

        try await fixture.load("/")
        try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics != nil }

        #expect(fixture.continueWatchingQueue.entries.isEmpty)
        #expect(fixture.continueWatchingQueue.updatedAt == nil)
        #expect(fixture.continueWatchingQueue.diagnostics?.contains("2010•Drama, Tanz") == true)
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
