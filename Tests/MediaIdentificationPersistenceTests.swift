import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Media identification persistence")
struct MediaIdentificationPersistenceTests {
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
}

@MainActor
struct IdentificationStores {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = URL(string: "https://example.com/watch/42")!
    let watchlist: WatchlistStore
    let watchlistFile: JSONFileStore<[WatchlistItem]>

    init() {
        watchlistFile = JSONFileStore(fileName: "watchlist.json", folderName: "Tests", baseDirectory: directory)
        watchlist = WatchlistStore(fileStore: watchlistFile)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }

    func coordinator(session: LetterboxdTestSession) -> MediaIdentificationCoordinator {
        MediaIdentificationCoordinator(
            watchlist: watchlist,
            client: TMDBClient(session: session)
        )
    }
}
