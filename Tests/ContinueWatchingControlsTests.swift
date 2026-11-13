import Foundation
import Testing
@testable import Wianu

@MainActor
struct ContinueWatchingControlsTests {
    @Test func `Provider accordions follow site order and show each service once`() throws {
        let fixture = try AnalyticsAppFixture(hasSites: false)
        defer { fixture.cleanup() }

        for (name, address) in [
            ("Disney+", "https://www.disneyplus.com/"),
            ("Netflix", "https://www.netflix.com/"),
            ("Netflix Profile", "https://www.netflix.com/browse"),
            ("HBO Max", "https://www.hbomax.com/")
        ] {
            #expect(fixture.model.siteStore.addSite(SiteDraft(name: name, address: address)))
        }

        let apple = try #require(fixture.model.continueWatchingQueues.first { $0.id == .appleTV })
        try apple.receive(json: "[]", from: #require(URL(string: "https://tv.apple.com/")))

        #expect(fixture.model.sidebarContinueWatchingQueues.map(\.id) == [.disneyPlus, .netflix, .hboMax, .appleTV])

        let disney = try #require(fixture.model.siteStore.sites.first)
        #expect(fixture.model.siteStore.updateSite(
            id: disney.id,
            with: SiteDraft(name: "Prime Video", address: "https://www.primevideo.com/")
        ))

        #expect(fixture.model.sidebarContinueWatchingQueues.map(\.id) == [.primeVideo, .netflix, .hboMax, .appleTV])
    }

    @Test func `Header refresh loads the provider home page and starts a bounded refresh`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        #expect(fixture.model.siteStore.addSite(SiteDraft(
            name: "HBO Max", address: "https://www.hbomax.com/video/watch/old-episode"
        )))

        fixture.model.refreshContinueWatching(.hboMax)

        #expect(fixture.model.destinationURL?.absoluteString == "https://www.hbomax.com/")
        #expect(fixture.model.continueWatchingQueues.first { $0.id == .hboMax }?.refreshID != nil)
    }

    @Test func `Provider sidebar entries open the episode returned by the provider`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let url = try #require(URL(string: "https://www.hbomax.com/"))
        let id = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let queue = try #require(fixture.model.continueWatchingQueues.first { $0.id == .hboMax })
        queue.receive(json: """
        [{"id":"00000000-0000-0000-0000-000000000001","title":"A Show","season":2,"episode":3}]
        """, from: url)
        fixture.model.select(.continueWatching(.hboMax, id.uuidString.lowercased()))

        #expect(fixture.model.destinationURL?.path == "/video/watch/00000000-0000-0000-0000-000000000001")
        #expect(queue.entries.count == 1)
    }
}
