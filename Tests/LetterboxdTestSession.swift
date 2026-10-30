import Foundation
@testable import Wianu

actor LetterboxdTestSession: TMDBSession {
    private let pages: [Data]
    private let fallback: [Data]
    private let movie: Data?
    private let statuses: [Int]
    private(set) var requests: [URLRequest] = []

    init(pages: [Data], fallback: [Data] = [], statuses: [Int] = [200], movie: Data? = nil) {
        self.movie = movie
        self.pages = pages
        self.fallback = fallback
        self.statuses = statuses
    }

    // TMDBSession requires an asynchronous method, even though this test response
    // is generated synchronously.
    // swiftlint:disable:next async_without_await
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let status = statuses[min(requests.count, statuses.count - 1)]
        requests.append(request)

        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: status,
                  httpVersion: nil,
                  headerFields: ["Retry-After": "1"]
              )
        else { throw URLError(.badURL) }

        if url.path.hasPrefix("/v1/movie/"), let movie {
            return (movie, response)
        }

        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let page = query.first { $0.name == "page" }?.value.flatMap(Int.init) ?? 1
        let isFallback = !query.contains { $0.name == "year" }
        let responses = isFallback && !fallback.isEmpty ? fallback : pages

        guard responses.indices.contains(page - 1) else { throw URLError(.badServerResponse) }

        return (responses[page - 1], response)
    }
}

nonisolated enum LetterboxdTestFixtures {
    static let emptyPage = Data("{\"page\":1,\"total_pages\":1,\"results\":[]}".utf8)
    static let enemy = Data("""
    {"page":1,"total_pages":1,"results":[
      {"id":181886,"title":"Enemy","original_title":"Enemy","release_date":"2014-03-14"}
    ]}
    """.utf8)
    static let collision = Data("""
    {"page":1,"total_pages":1,"results":[
      {"id":344656,"title":"Enemy Empire","release_date":"2013-12-27"},
      {"id":522815,"title":"Enemy","release_date":"2013-08-30"}
    ]}
    """.utf8)

    static func item(_ title: String = "Enemy", year: Int? = 2013) -> WatchlistItem {
        WatchlistItem(
            title: title,
            year: year,
            letterboxdURL: URL(string: "https://boxd.it/5xtO")!,
            addedAt: nil,
            sourceOrder: 0
        )
    }
}
