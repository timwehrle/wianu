import Foundation
import Testing
@testable import Wianu

@MainActor
struct ContinueWatchingControlsTests {
    @Test func `Using the current page preserves the entry and prevents playback from replacing its link`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let episodeURL = try #require(URL(string: "https://private.example/player/episode"))
        let showURL = try #require(URL(string: "https://private.example/show/series"))
        let item = fixture.model.continueWatchingStore.save(
            siteID: fixture.site.id, title: "My Show", url: episodeURL
        )
        let media = IdentificationFixtures.media()
        fixture.model.continueWatchingStore.associate(id: item.id, with: media)
        fixture.model.select(.site(fixture.site.id))
        fixture.model.currentPageURL = showURL

        #expect(fixture.model.canUseCurrentPage(for: item))

        fixture.model.useCurrentPage(for: item)
        fixture.model.saveAutomaticallyToContinueWatching(title: "Detected Title", url: episodeURL)

        let updated = try #require(fixture.model.continueWatchingStore.item(id: item.id))

        #expect(fixture.model.continueWatchingStore.items.count == 1)
        #expect(updated.url == showURL)
        #expect(updated.title == "My Show")
        #expect(updated.tmdbMetadata == media)
        #expect(updated.siteID == fixture.site.id)
        #expect(updated.dateAdded == item.dateAdded)
    }

    @Test func `Use Current Page rejects home another provider and another saved destination`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let originalURL = try #require(URL(string: "https://private.example/player/episode"))
        let item = fixture.model.continueWatchingStore.save(siteID: fixture.site.id, title: "My Show", url: originalURL)
        fixture.model.currentPageURL = originalURL
        fixture.model.select(.home)

        #expect(!fixture.model.canUseCurrentPage(for: item))

        fixture.model.select(.site(fixture.site.id))
        fixture.model.currentPageURL = URL(string: "https://other.example/show")
        fixture.model.useCurrentPage(for: item)

        #expect(fixture.model.continueWatchingStore.item(id: item.id)?.url == originalURL)

        let otherURL = try #require(URL(string: "https://private.example/show/other"))
        fixture.model.continueWatchingStore.save(siteID: fixture.site.id, title: "Other", url: otherURL)
        fixture.model.currentPageURL = otherURL

        #expect(!fixture.model.canUseCurrentPage(for: item))
    }

    @Test func `Disabling automatic saving preserves existing entries and manual saving`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let existingURL = try #require(URL(string: "https://private.example/first"))
        let newURL = try #require(URL(string: "https://private.example/second"))
        let item = fixture.model.continueWatchingStore.save(
            siteID: fixture.site.id,
            title: "Existing",
            url: existingURL
        )
        fixture.defaults.set(false, forKey: ContinueWatchingPreference.automaticSavingKey)

        fixture.model.saveAutomaticallyToContinueWatching(title: "Automatic", url: newURL)

        #expect(fixture.model.continueWatchingStore.items.count == 1)
        #expect(fixture.model.continueWatchingStore.item(id: item.id) != nil)
        #expect(fixture.defaults.object(forKey: ContinueWatchingPreference.automaticSavingKey) as? Bool == false)

        fixture.model.toggleContinueWatching(title: "Manual", url: newURL)

        #expect(fixture.model.continueWatchingStore.item(matching: newURL)?.title == "Manual")
    }
}
