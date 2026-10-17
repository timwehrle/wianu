import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Automatic media identification")
struct MediaIdentificationCoordinatorTests {
    @Test func `saving remains immediate and associates in background`() async throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let session = try LetterboxdTestSession(pages: [IdentificationFixtures.page([IdentificationFixtures.media()])])
        let coordinator = stores.coordinator(session: session)
        let item = stores.watchlist.add(title: "Severance", year: 2022, url: stores.url)
        coordinator.identifyInBackground(.watchlist(item.id))
        #expect(stores.watchlist.item(id: item.id)?.tmdbID == nil)
        try await waitUntil { stores.watchlist.item(id: item.id)?.tmdbID != nil }
        #expect(stores.watchlist.item(id: item.id)?.tmdbMediaType == .tv)
    }

    @Test func `ambiguity preserves entry for manual review`() async throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let page = try IdentificationFixtures.page([
            IdentificationFixtures.media(),
            IdentificationFixtures.media(type: .movie)
        ])
        let session = LetterboxdTestSession(pages: [page])
        let coordinator = stores.coordinator(session: session)
        let item = stores.continueWatching.save(siteID: nil, title: "Severance", url: stores.url)
        let target = MediaIdentificationTarget.continueWatching(item.id)
        coordinator.identifyInBackground(target)
        try await waitUntil { coordinator.needsReview(target) }
        #expect(stores.continueWatching.item(id: item.id)?.tmdbID == nil)
        coordinator.associate(IdentificationFixtures.media(), with: target)
        #expect(!coordinator.needsReview(target) && coordinator.isIdentified(target))
    }

    @Test func `confirmed matches are reused across lists without searching`() async {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let session = LetterboxdTestSession(pages: [])
        let coordinator = stores.coordinator(session: session)
        let playing = stores.continueWatching.save(siteID: nil, title: "Severance", url: stores.url)
        stores.continueWatching.associate(id: playing.id, with: IdentificationFixtures.media())
        let saved = stores.watchlist.add(title: "Severance", year: nil, url: stores.url)
        coordinator.identifyInBackground(.watchlist(saved.id))
        #expect(stores.watchlist.item(id: saved.id)?.tmdbMediaType == .tv)
        #expect(await session.requests.isEmpty)
    }

    @Test func `late search cannot override user confirmation`() async throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let session = try LetterboxdTestSession(pages: [IdentificationFixtures.page([IdentificationFixtures.media()])])
        let coordinator = stores.coordinator(session: session)
        let item = stores.watchlist.add(title: "Severance", year: 2022, url: stores.url)
        let target = MediaIdentificationTarget.watchlist(item.id)
        coordinator.identifyInBackground(target)
        coordinator.associate(IdentificationFixtures.media(id: 99), with: target)
        try await Task.sleep(for: .milliseconds(450))
        #expect(stores.watchlist.item(id: item.id)?.tmdbID == 99)
    }

    @Test func `edited and deleted entries reject stale results`() async throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let session = try LetterboxdTestSession(pages: [IdentificationFixtures.page([IdentificationFixtures.media()])])
        let coordinator = stores.coordinator(session: session)
        let edited = stores.watchlist.add(title: "Severance", year: 2022, url: nil)
        let deleted = stores.watchlist.add(title: "Severance", year: 2022, url: stores.url)
        coordinator.identifyInBackground(.watchlist(edited.id))
        coordinator.identifyInBackground(.watchlist(deleted.id))
        stores.watchlist.update(id: edited.id, title: "Another title", year: nil, url: nil)
        stores.watchlist.remove(id: deleted.id)
        try await Task.sleep(for: .milliseconds(500))
        #expect(stores.watchlist.item(id: edited.id)?.tmdbID == nil)
        #expect(stores.watchlist.item(id: deleted.id) == nil)
    }

    @Test func `network failure does not prevent saving`() async throws {
        let stores = IdentificationStores()
        defer { stores.cleanup() }
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.emptyPage], statuses: [400])
        let coordinator = stores.coordinator(session: session)
        let item = stores.watchlist.add(title: "Severance", year: nil, url: stores.url)
        let target = MediaIdentificationTarget.watchlist(item.id)
        coordinator.identifyInBackground(target)
        try await waitUntil { coordinator.errors[target] != nil }
        #expect(stores.watchlist.item(id: item.id)?.title == "Severance")
        #expect(coordinator.needsReview(target))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0 ..< 100 {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Identification did not complete in time")
    }
}
