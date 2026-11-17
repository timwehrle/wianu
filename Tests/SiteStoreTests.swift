import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Site ordering")
struct SiteStoreTests {
    @Test(arguments: [
        ([0], 4, [1, 2, 3, 0]),
        ([3], 0, [3, 0, 1, 2]),
        ([0, 2], 4, [1, 3, 0, 2]),
        ([1], 2, [0, 1, 2, 3])
    ])
    func `moving sites preserves their data and persists order`(
        sourceIndices: [Int],
        destinationIndex: Int,
        expectedIndices: [Int]
    ) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileStore = JSONFileStore<[SavedSite]>(
            fileName: "sites.json",
            folderName: "Tests",
            baseDirectory: directory
        )
        let sites = (0 ..< 4).map { index in
            SavedSite(
                name: "Site \(index)",
                urlString: "https://example.com/\(index)",
                searchURLTemplate: "https://example.com/\(index)?q={query}",
                createdAt: Date(timeIntervalSince1970: 1000)
            )
        }
        let expectedSites = expectedIndices.map { sites[$0] }

        try fileStore.save(sites)

        let store = SiteStore(fileStore: fileStore)
        try #require(store.sites == sites)

        store.moveSites(fromOffsets: IndexSet(sourceIndices), toOffset: destinationIndex)

        #expect(store.sites == expectedSites)
        #expect(store.persistenceError == nil)

        let reopenedStore = SiteStore(fileStore: fileStore)

        #expect(reopenedStore.sites == expectedSites)
        #expect(reopenedStore.persistenceError == nil)
    }

    @Test
    func `failed save keeps the original order`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileStore = JSONFileStore<[SavedSite]>(
            fileName: "sites.json",
            folderName: "Tests",
            baseDirectory: directory
        )
        let sites = [
            SavedSite(
                name: "First",
                urlString: "https://first.example",
                createdAt: Date(timeIntervalSince1970: 1000)
            ),
            SavedSite(
                name: "Second",
                urlString: "https://second.example",
                createdAt: Date(timeIntervalSince1970: 2000)
            )
        ]

        try fileStore.save(sites)

        let store = SiteStore(fileStore: fileStore)
        try #require(store.sites == sites)

        // A file in place of the storage directory makes the next save fail deterministically.
        try FileManager.default.removeItem(at: directory)
        try Data().write(to: directory)

        store.moveSites(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        #expect(store.sites == sites)
        #expect(store.persistenceError != nil)
    }
}
