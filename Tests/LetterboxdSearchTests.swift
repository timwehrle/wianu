import Foundation
import Testing
@testable import Wianu

@Suite("Letterboxd search")
struct LetterboxdSearchTests {
    @Test func `unfiltered search preserves incorrect imported year for review`() async throws {
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.enemy])
        let result = try await LetterboxdMatcher.search(
            LetterboxdTestFixtures.item(), client: TMDBClient(session: session)
        )

        #expect(result.selectedID == nil && result.reviewReason != nil)

        #expect(result.resolvedItem.year == 2013)
        let requests = await session.requests

        #expect(requests.count == 1)
        let url = try #require(requests.first?.url)
        let parameters = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        #expect(parameters?.contains { $0.name == "year" } == false)
    }

    @Test func `candidate order does not change search decisions`() async throws {
        let exact = TMDBMediaResult(
            id: 1,
            mediaType: .movie,
            title: "Enemy",
            overview: "",
            posterPath: nil,
            releaseDate: "2013"
        )
        let unrelated = TMDBMediaResult(
            id: 2,
            mediaType: .movie,
            title: "Enemy Empire",
            overview: "",
            posterPath: nil,
            releaseDate: "2013"
        )

        for candidates in [[exact, unrelated], [unrelated, exact]] {
            let session = try LetterboxdTestSession(pages: [IdentificationFixtures.page(candidates)])
            let result = try await LetterboxdMatcher.search(
                LetterboxdTestFixtures.item(), client: TMDBClient(session: session)
            )

            #expect(result.selectedID == 1)

            #expect(await session.requests.count == 1)
        }
    }

    @Test func `search pagination is bounded and incomplete searches require review`() async throws {
        let page = Data("""
        {"page":1,"total_pages":6,"results":[
        {"id":1,"title":"Enemy","release_date":"2013"}]}
        """.utf8)
        let session = LetterboxdTestSession(pages: Array(repeating: page, count: 5))
        let result = try await LetterboxdMatcher.search(
            LetterboxdTestFixtures.item(), client: TMDBClient(session: session)
        )

        #expect(result.selectedID == nil && result.reviewReason != nil)

        #expect(await session.requests.count == 5)
    }

    @Test func `explicit movie link uses one details request without title inference`() async throws {
        let session = LetterboxdTestSession(pages: [], movie: Data("""
        {"id":181886,"title":"Enemy","releaseDate":"2014-03-14","overview":""}
        """.utf8))
        let item = try WatchlistItem(
            title: "Original imported title",
            year: nil,
            letterboxdURL: #require(URL(string: "https://letterboxd.com/tmdb/181886")),
            addedAt: nil,
            sourceOrder: 0
        )
        let result = try await LetterboxdMatcher.search(item, client: TMDBClient(session: session))

        #expect(result.selectedID == 181_886)

        #expect(result.resolvedItem.title == item.title && result.resolvedItem.year == nil)
        let requests = await session.requests

        #expect(requests.count == 1 && requests.first?.url?.path == "/v1/movie/181886")
    }

    @Test func `no search results preserves an unmatched entry with one request`() async throws {
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.emptyPage])
        let item = LetterboxdTestFixtures.item()
        let result = try await LetterboxdMatcher.search(item, client: TMDBClient(session: session))

        #expect(result.classification == .unmatched && result.resolvedItem == item)

        #expect(await session.requests.count == 1)
    }

    @Test func `identifier failure does not fall back to a title guess`() async throws {
        let session = LetterboxdTestSession(pages: [], statuses: [404], movie: Data("{}".utf8))
        let query = MediaIdentificationQuery(title: "Enemy", year: 2013, mediaType: .movie, movieID: 1)

        await #expect(throws: TMDBError.server(statusCode: 404, message: nil)) {
            _ = try await MediaIdentificationService(client: TMDBClient(session: session)).search(query)
        }

        #expect(await session.requests.count == 1)
    }

    @Test func `rate limits and server errors recover with bounded retries`() async throws {
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.enemy], statuses: [429, 503, 200])
        let result = try await TMDBClient(session: session).searchMovies(query: "Enemy", year: 2013)

        #expect(result.results.first?.id == 181_886)

        #expect(await session.requests.count == 3)
    }

    @Test func `permanent errors are not retried`() async {
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.enemy], statuses: [400])

        await #expect(throws: TMDBError.server(statusCode: 400, message: nil)) {
            _ = try await TMDBClient(session: session).searchMovies(query: "Enemy", year: 2013)
        }

        #expect(await session.requests.count == 1)
    }

    @Test func `cancellation stops rate limit backoff`() async throws {
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.enemy], statuses: [429])
        let task = Task { try await TMDBClient(session: session).searchMovies(query: "Enemy", year: 2013) }
        try await Task.sleep(for: .milliseconds(450))
        task.cancel()

        await #expect(throws: CancellationError.self) { _ = try await task.value }

        #expect(await session.requests.count == 1)
    }
}
