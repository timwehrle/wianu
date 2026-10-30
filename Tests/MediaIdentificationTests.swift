import Foundation
import Testing
@testable import Wianu

@Suite("Shared media identification")
struct MediaIdentificationTests {
    @Test func `episode titles produce TV queries without changing saved names`() {
        let original = "Severance (2022) - S01E03 In Perpetuity"
        let query = MediaIdentificationQuery.savedTitle(original)

        #expect(query.title == "Severance" && query.year == 2022 && query.mediaType == .tv)

        #expect(MediaIdentificationQuery.savedTitle("2001: A Space Odyssey").title == "2001: A Space Odyssey")

        #expect(MediaIdentificationQuery.savedTitle("Waves [2019]").year == 2019)

        #expect(MediaIdentificationQuery.savedTitle("Show - Season 1 Episode 2").title == "Show")
    }

    @Test func `only recognised movie links supply identifiers`() {
        for link in ["https://letterboxd.com/tmdb/42", "https://www.themoviedb.org/movie/42-title"] {
            let query = MediaIdentificationQuery.savedTitle("Saved title", url: URL(string: link))

            #expect(query.movieID == 42)
        }

        for link in [
            "https://example.com/movie/42",
            "https://letterboxd.com.evil.test/tmdb/42",
            "https://letterboxd.com/tmdb/0",
            "https://letterboxd.com/tmdb/42/extra",
            "https://www.themoviedb.org/tv/42"
        ] {
            #expect(MediaIdentificationQuery.savedTitle("Saved title", url: URL(string: link)).movieID == nil)
        }
    }

    @Test func `movies and shows with the same numeric ID remain distinct`() {
        let movie = IdentificationFixtures.media(type: .movie)
        let show = IdentificationFixtures.media(type: .tv)

        #expect(movie.identity != show.identity)
        let query = MediaIdentificationQuery(title: "Severance", year: 2022, mediaType: nil)

        #expect(MediaMatcher.match(query, candidates: [movie, show], complete: true) == nil)

        #expect(MediaMatcher.match(query, candidates: [show, show], complete: true)?.identity == show.identity)
    }

    @Test func `TV identification filters movie results`() async throws {
        let show = IdentificationFixtures.media(type: .tv)
        let session = try LetterboxdTestSession(pages: [IdentificationFixtures.page([
            IdentificationFixtures.media(type: .movie), show
        ])])
        let query = MediaIdentificationQuery(title: "Severance", year: 2022, mediaType: .tv)
        let result = try await MediaIdentificationService(client: TMDBClient(session: session)).search(query)

        #expect(result.match?.identity == show.identity)

        #expect(result.candidates.count == 1)
        let url = try #require(await session.requests.first?.url)

        #expect(url.path == "/v1/search/multi")
    }

    @Test func `manual watchlist can identify either movies or shows`() async throws {
        let show = IdentificationFixtures.media(type: .tv)
        let session = try LetterboxdTestSession(pages: [IdentificationFixtures.page([show])])
        let query = MediaIdentificationQuery(title: "Severance", year: nil, mediaType: nil)
        let result = try await MediaIdentificationService(client: TMDBClient(session: session)).search(query)

        #expect(result.match == nil && result.candidates.first?.identity == show.identity)
    }

    @Test func `ambiguous and incomplete searches are never automatically accepted`() async throws {
        let candidates = [IdentificationFixtures.media(type: .movie), IdentificationFixtures.media(type: .tv)]
        let query = MediaIdentificationQuery(title: "Severance", year: 2022, mediaType: nil)
        let session = try LetterboxdTestSession(pages: [IdentificationFixtures.page(candidates)])
        let result = try await MediaIdentificationService(client: TMDBClient(session: session)).search(query)

        #expect(result.match == nil && result.reviewReason != nil)

        #expect(MediaMatcher.match(query, candidates: [candidates[0]], complete: false) == nil)
    }
}

nonisolated enum IdentificationFixtures {
    static func media(type: TMDBMediaType = .tv, id: Int = 42) -> TMDBMediaResult {
        TMDBMediaResult(
            id: id,
            mediaType: type,
            title: "Severance",
            overview: "Description",
            posterPath: nil,
            releaseDate: "2022-02-18"
        )
    }

    static func page(_ results: [TMDBMediaResult]) throws -> Data {
        struct Page: Encodable {
            let page = 1
            let totalPages = 1
            let results: [TMDBMediaResult]
            enum CodingKeys: String, CodingKey {
                case page, results
                case totalPages = "total_pages"
            }
        }

        return try JSONEncoder().encode(Page(results: results))
    }
}
