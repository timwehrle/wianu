import Foundation
import Testing
@testable import Wianu

@Suite("Letterboxd import")
struct LetterboxdImportTests {
    @Test func `quoted fields and duplicates preserve original information`() throws {
        let csv = #"""
        Name,Year,Letterboxd URI
        "Film, One",2001,https://letterboxd.com/film/one/
        Duplicate,2001,https://letterboxd.com/film/one/
        "Film ""Two""",2002,https://letterboxd.com/film/two/
        """#
        let result = try LetterboxdWatchlistImporter.importItems(from: Data(csv.utf8))

        #expect(result.items.map(\.title) == ["Film, One", "Film \"Two\""])
        #expect(result.items.map(\.year) == [2001, 2002])
        #expect(result.skippedRowCount == 1)
    }

    @Test func `malformed CSV still reports import error`() {
        #expect(throws: LetterboxdWatchlistImportError.self) {
            _ = try LetterboxdWatchlistImporter.importItems(from: Data("Name,Letterboxd URI\n\"unclosed".utf8))
        }
    }

    @Test func `confirmed metadata survives edits reordering and persistence`() throws {
        var item = LetterboxdTestFixtures.item()
        item.tmdbID = 181_886
        item.tmdbMetadata = try JSONDecoder().decode(TMDBMovieSearchResponse.self, from: LetterboxdTestFixtures.enemy)
            .results.first?.media
        let edited = item.updating(title: "Original CSV title", year: 2013, url: item.url).withSourceOrder(7)
        let restored = try JSONDecoder().decode(WatchlistItem.self, from: JSONEncoder().encode(edited))

        #expect(restored == edited)
        #expect(restored.id == item.id)
        #expect(restored.tmdbID == 181_886 && restored.tmdbMetadata == item.tmdbMetadata)
    }

    @Test func `legacy watchlist still decodes`() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","title":"Legacy","sourceOrder":0,
         "letterboxdURL":"https://letterboxd.com/film/legacy/"}
        """
        let item = try JSONDecoder().decode(WatchlistItem.self, from: Data(json.utf8))

        #expect(item.tmdbID == nil && item.url != nil && item.source == .letterboxd)
    }

    @Test func `duplicate import makes no search requests`() async throws {
        let url = try temporaryCSV()

        defer { try? FileManager.default.removeItem(at: url) }
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.enemy])
        let model = LetterboxdImportModel()
        await model.load(
            from: url,
            existingItems: [LetterboxdTestFixtures.item()],
            client: TMDBClient(session: session)
        )

        #expect(model.skippedCount == 1)
        #expect(model.entries.isEmpty && !model.isLoading)
        #expect(model.message != nil)
        #expect(await session.requests.isEmpty)
    }

    @Test func `failed search keeps original entry`() async throws {
        let url = try temporaryCSV()

        defer { try? FileManager.default.removeItem(at: url) }
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.enemy], statuses: [400])
        let model = LetterboxdImportModel()
        await model.load(from: url, existingItems: [], client: TMDBClient(session: session))
        let result = try #require(model.entries.first)

        #expect(result.item.title == "Enemy" && result.item.year == 2013)
        #expect(result.error != nil && result.selectedID == nil)
        #expect(model.completedCount == 1 && !model.isLoading)
    }

    @Test func `cancelled import discards pending entries`() async throws {
        let url = try temporaryCSV()

        defer { try? FileManager.default.removeItem(at: url) }
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.enemy], statuses: [429])
        let model = LetterboxdImportModel()
        let task = Task { await model.load(from: url, existingItems: [], client: TMDBClient(session: session)) }
        try await Task.sleep(for: .milliseconds(450))
        task.cancel()
        await task.value

        #expect(model.entries.isEmpty && model.message == nil && !model.isLoading)
    }

    private func temporaryCSV() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
        try "Name,Year,Letterboxd URI\nEnemy,2013,https://boxd.it/5xtO\n".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )

        return url
    }
}
