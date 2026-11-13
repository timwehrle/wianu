import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Media identification persistence")
struct MediaIdentificationPersistenceTests {
    @Test func `associations preserve continue watching fields and survive reload`() throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let provider = UUID()
        let saved = stores.continueWatching.save(
            siteID: provider,
            title: "Original page title",
            url: stores.url
        )
        let media = IdentificationFixtures.media()
        stores.continueWatching.associate(id: saved.id, with: media)
        let updated = try #require(stores.continueWatching.item(id: saved.id))
        #expect(updated.title == saved.title && updated.url == saved.url && updated.siteID == provider)
        #expect(updated.dateAdded == saved.dateAdded && updated.lastOpenedAt == saved.lastOpenedAt)
        #expect(updated.tmdbID == media.id && updated.tmdbMediaType == .tv)
        let reopened = ContinueWatchingStore(fileStore: stores.continueWatchingFile)
        let restored = try #require(reopened.item(id: saved.id))
        #expect(restored.tmdbMetadata == updated.tmdbMetadata && restored.tmdbMediaType == .tv)
        #expect(restored.url == saved.url && restored.siteID == provider && restored.title == saved.title)
        // The existing JSON store writes ISO 8601 dates at whole-second precision.
        #expect(abs(restored.dateAdded.timeIntervalSince(saved.dateAdded)) < 1)
        #expect(abs(restored.lastOpenedAt.timeIntervalSince(saved.lastOpenedAt)) < 1)
        stores.continueWatching.associate(id: saved.id, with: nil)
        #expect(stores.continueWatching.item(id: saved.id)?.tmdbID == nil)
        #expect(stores.continueWatching.item(id: saved.id)?.tmdbMetadata == nil)
    }

    @Test(arguments: [
        "https://www.netflix.com/watch/123?trackId=456",
        "https://www.netflix.com/title/123?trackId=789",
        "https://www.netflix.com/browse?jbv=123&trackId=456",
        "https://netflix.com/title/123"
    ])
    func `Netflix title links match the same saved item`(link: String) throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }

        let originalURL = try #require(URL(string: "https://www.netflix.com/title/123?trackId=111"))
        let item = stores.continueWatching.save(siteID: nil, title: "Star Trek Beyond", url: originalURL)
        let playbackURL = try #require(URL(string: link))
        let reopened = ContinueWatchingStore(fileStore: stores.continueWatchingFile)

        #expect(reopened.item(matching: playbackURL)?.id == item.id)

        reopened.save(siteID: nil, title: "Star Trek Beyond", url: playbackURL)

        #expect(reopened.items.count == 1)
        #expect(reopened.items.first?.id == item.id)
    }

    @Test(arguments: [
        "https://www.netflix.com/title/456",
        "https://www.netflix.com/browse?jbv=invalid",
        "https://other.example/title/123"
    ])
    func `Unrelated pages do not match a saved Netflix title`(link: String) throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }

        let originalURL = try #require(URL(string: "https://www.netflix.com/title/123"))
        stores.continueWatching.save(siteID: nil, title: "Star Trek Beyond", url: originalURL)

        let unrelatedURL = try #require(URL(string: link))

        #expect(stores.continueWatching.item(matching: unrelatedURL) == nil)
    }

    @Test func `Replacing a saved link persists its playback identity and preserves metadata`() throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }

        let item = stores.continueWatching.save(siteID: nil, title: "My Show", url: stores.url)
        let showURL = try #require(URL(string: "https://example.com/show/42"))
        let revisedURL = try #require(URL(string: "https://example.com/show/42/details"))
        let media = IdentificationFixtures.media()
        stores.continueWatching.associate(id: item.id, with: media)
        stores.continueWatching.replaceURL(id: item.id, with: showURL)
        stores.continueWatching.replaceURL(id: item.id, with: revisedURL)

        let reopened = ContinueWatchingStore(fileStore: stores.continueWatchingFile)
        let restored = try #require(reopened.item(matching: stores.url))

        #expect(restored.id == item.id)
        #expect(restored.url == revisedURL)
        #expect(restored.title == "My Show")
        #expect(restored.tmdbMetadata == media)
        #expect(reopened.item(matching: revisedURL)?.id == item.id)
    }

    @Test func `manual watchlist persists both ID and media type`() throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let item = stores.watchlist.add(title: "Saved name", year: 2022, url: stores.url)
        let media = IdentificationFixtures.media()
        stores.watchlist.associate(id: item.id, with: media)
        let reopened = WatchlistStore(fileStore: stores.watchlistFile)
        let restored = try #require(reopened.item(id: item.id))
        #expect(restored.tmdbID == media.id && restored.tmdbMediaType == .tv)
        #expect(restored.title == item.title && restored.url == item.url && restored.year == item.year)
        #expect(restored.sourceOrder == item.sourceOrder)
        let restoredDate = try #require(restored.addedAt)
        let savedDate = try #require(item.addedAt)
        #expect(abs(restoredDate.timeIntervalSince(savedDate)) < 1)
    }

    @Test func `legacy continue watching data still loads`() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","title":"Old title",
         "url":"https://example.com/watch/42","dateAdded":0,"lastOpenedAt":0}
        """
        let item = try JSONDecoder().decode(ContinueWatchingItem.self, from: Data(json.utf8))
        #expect(item.tmdbID == nil && item.tmdbMediaType == nil && item.tmdbMetadata == nil)
        #expect(item.title == "Old title")
    }
}

@MainActor
struct IdentificationStores {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = URL(string: "https://example.com/watch/42")!
    let watchlist: WatchlistStore
    let continueWatching: ContinueWatchingStore
    let watchlistFile: JSONFileStore<[WatchlistItem]>
    let continueWatchingFile: JSONFileStore<[ContinueWatchingItem]>

    init() {
        watchlistFile = JSONFileStore(fileName: "watchlist.json", folderName: "Tests", baseDirectory: directory)
        continueWatchingFile = JSONFileStore(fileName: "continue.json", folderName: "Tests", baseDirectory: directory)
        watchlist = WatchlistStore(fileStore: watchlistFile)
        continueWatching = ContinueWatchingStore(fileStore: continueWatchingFile)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }

    func coordinator(session: LetterboxdTestSession) -> MediaIdentificationCoordinator {
        MediaIdentificationCoordinator(
            watchlist: watchlist,
            continueWatching: continueWatching,
            client: TMDBClient(session: session)
        )
    }
}
