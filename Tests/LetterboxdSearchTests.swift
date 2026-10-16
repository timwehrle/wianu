import Foundation
import Testing
@testable import Wianu

@Suite("Letterboxd search")
struct LetterboxdSearchTests {
    @Test func `sole fallback is selected and preserves imported year`() async throws {
        let session = LetterboxdTestSession(
            pages: [LetterboxdTestFixtures.emptyPage],
            fallback: [LetterboxdTestFixtures.enemy]
        )
        let result = try await LetterboxdMatcher.search(
            LetterboxdTestFixtures.item(),
            client: TMDBClient(session: session)
        )

        #expect(result.selectedID == 181_886)
        #expect(result.resolvedItem.year == 2013)
        #expect(result.reviewReason == nil)
        #expect(result.candidates.first?.mediaType == .movie)
        let requests = await session.requests

        #expect(requests.count == 2)
        let focusedURL = try #require(requests.first?.url)

        #expect(focusedURL.path == "/v1/search/movie")
        let focusedQuery = URLComponents(url: focusedURL, resolvingAgainstBaseURL: false)?.queryItems

        #expect(focusedQuery?.contains(URLQueryItem(name: "year", value: "2013")) == true)
        let fallbackURL = try #require(requests.last?.url)
        let fallbackQuery = URLComponents(url: fallbackURL, resolvingAgainstBaseURL: false)?.queryItems

        #expect(fallbackQuery?.contains { $0.name == "year" } == false)
    }

    @Test func `incomplete fallback requires review`() async throws {
        let partial = try Data(#require(String(data: LetterboxdTestFixtures.enemy, encoding: .utf8)?
                .replacingOccurrences(of: "\"total_pages\":1", with: "\"total_pages\":2").utf8))
        let session = LetterboxdTestSession(pages: [LetterboxdTestFixtures.emptyPage], fallback: [partial])
        let result = try await LetterboxdMatcher.search(
            LetterboxdTestFixtures.item(),
            client: TMDBClient(session: session)
        )

        #expect(result.selectedID == nil)
        #expect(result.classification == .ambiguous)
    }

    @Test func `lower ranked same title and year requires review`() async throws {
        let session = LetterboxdTestSession(
            pages: [LetterboxdTestFixtures.collision],
            fallback: [LetterboxdTestFixtures.enemy]
        )
        let result = try await LetterboxdMatcher.search(
            LetterboxdTestFixtures.item(),
            client: TMDBClient(session: session)
        )

        #expect(result.selectedID == nil)
        #expect(result.classification == .ambiguous)
        #expect(result.candidates.contains { $0.id == 181_886 })
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
