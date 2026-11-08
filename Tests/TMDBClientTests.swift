import Foundation
import Testing
@testable import Wianu

private actor FixtureSession: TMDBSession {
    let status: Int
    let headers: [String: String]
    let data: Data
    private(set) var request: URLRequest?

    init(_ json: String, status: Int = 200, headers: [String: String] = [:]) {
        self.status = status
        self.headers = headers
        data = Data(json.utf8)
    }

    // Required to be async by TMDBSession.
    // swiftlint:disable:next async_without_await
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: headers
        )!
        return (data, response)
    }

    func capturedRequest() -> URLRequest? {
        request
    }
}

private actor CancelledSession: TMDBSession {
    // Required to be async by TMDBSession.
    // swiftlint:disable:next async_without_await
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.cancelled)
    }
}

@Suite("TMDB client")
struct TMDBClientTests {
    @Test func `empty weekly archive has no movies`() async throws {
        let session = FixtureSession(#"{"weeks":[]}"#)
        let movies = try await TMDBClient(session: session).weeklyMovies()
        #expect(movies.isEmpty)
        let request = await session.capturedRequest()
        #expect(request?.url?.path == "/v1/weekly")
    }

    @Test func `weekly movie details decode camel case API fields`() throws {
        let data = Data(
            #"{"id":42,"title":"Film","overview":"Story","posterPath":"/poster.jpg","releaseDate":"2026-01-01"}"#
                .utf8
        )
        let movie = try JSONDecoder().decode(WeeklyMovieResponse.self, from: data)
        #expect(movie.posterPath == "/poster.jpg")
        #expect(movie.backdropPath == nil)
        #expect(movie.releaseDate == "2026-01-01")
    }

    @Test func `backdrop artwork survives metadata persistence`() throws {
        let data = Data(
            #"{"id":42,"media_type":"movie","title":"Film","backdrop_path":"/scene.jpg"}"#.utf8
        )
        let media = try JSONDecoder().decode(TMDBMediaResult.self, from: data)
        #expect(media.backdropPath == "/scene.jpg")
        let restored = try JSONDecoder().decode(TMDBMediaResult.self, from: JSONEncoder().encode(media))
        #expect(restored == media)

        let legacy = Data(#"{"id":42,"media_type":"movie","title":"Film"}"#.utf8)
        #expect(try JSONDecoder().decode(TMDBMediaResult.self, from: legacy).backdropPath == nil)
    }

    @Test func `weekly movie details include landscape artwork when available`() throws {
        let data = Data(#"{"id":42,"title":"Film","overview":"Story","backdropPath":"/scene.jpg"}"#.utf8)
        let movie = try JSONDecoder().decode(WeeklyMovieResponse.self, from: data)
        #expect(movie.backdropPath == "/scene.jpg")
    }

    @Test func `backdrops use a landscape image size`() throws {
        let baseURL = try #require(URL(string: "https://image.tmdb.org/t/p/"))
        let configuration = TMDBImageConfiguration(secureBaseURL: baseURL, posterSize: "w342", logoSize: "w92")
        #expect(configuration.backdropURL(path: "/scene.jpg")?.absoluteString
            == "https://image.tmdb.org/t/p/w1280/scene.jpg")
        #expect(configuration.backdropURL(path: nil) == nil)
    }

    @Test func `cancelled URL requests are not shown as search errors`() async throws {
        let defaults = try #require(UserDefaults(
            suiteName: "TMDBClientTests.cancelled.\(UUID().uuidString)"
        ))
        let model = TMDBSearchModel(
            client: TMDBClient(session: CancelledSession()),
            userDefaults: defaults
        )

        model.query = "Dune"
        model.queryChanged()
        try? await Task.sleep(for: .milliseconds(500))

        #expect(model.errorMessage == nil)
        #expect(!model.isSearching)
    }

    @Test func `search is loading during debounce and stops when cleared`() throws {
        let defaults = try #require(UserDefaults(
            suiteName: "TMDBClientTests.debounce.\(UUID().uuidString)"
        ))
        let model = TMDBSearchModel(
            client: TMDBClient(session: CancelledSession()),
            userDefaults: defaults
        )

        model.query = "Dune"
        model.queryChanged()
        #expect(model.isSearching)
        #expect(model.results.isEmpty)
        #expect(model.errorMessage == nil)

        model.query = ""
        model.queryChanged()
        #expect(!model.isSearching)
        #expect(!model.isLoadingMore)
        #expect(model.results.isEmpty)
    }

    @Test func `Letterboxd links are available only for movies`() {
        let movie = TMDBMediaResult(
            id: 550,
            mediaType: .movie,
            title: "Fight Club",
            overview: "",
            posterPath: nil,
            releaseDate: "1999-10-15"
        )
        let show = TMDBMediaResult(
            id: 1396,
            mediaType: .tv,
            title: "Breaking Bad",
            overview: "",
            posterPath: nil,
            releaseDate: "2008-01-20"
        )

        #expect(
            movie.letterboxdURL
                == URL(string: "https://letterboxd.com/tmdb/550")
        )
        #expect(show.letterboxdURL == nil)
    }

    @Test func `search uses backend encodes and filters people`() async throws {
        let session = FixtureSession("""
        {"page":1,"total_pages":2,"results":[
          {"id":1,"media_type":"movie","title":"Dune","overview":"x",
           "poster_path":"/p.jpg","release_date":"2021-10-22"},
          {"id":2,"media_type":"tv","name":"Dark","overview":"y",
           "first_air_date":"2017-12-01"},
          {"id":3,"media_type":"person","name":"Someone"}
        ]}
        """)
        let client = try TMDBClient(
            session: session,
            baseURL: #require(URL(string: "https://example.test/v1")),
            language: "de-DE"
        )

        let page = try await client.search(query: "A & B")

        #expect(page.results.map(\.title) == ["Dune", "Dark"])
        #expect(page.totalPages == 2)
        let request = await session.capturedRequest()
        #expect(request?.value(forHTTPHeaderField: "Authorization") == nil)
        let components = try URLComponents(url: #require(request?.url), resolvingAgainstBaseURL: false)
        #expect(components?.queryItems?.contains(URLQueryItem(name: "query", value: "A & B")) == true)
        #expect(components?.queryItems?.contains(URLQueryItem(name: "include_adult", value: "false")) == true)
    }

    @Test func `groups provider offers and handles missing region`() async throws {
        let session = FixtureSession("""
        {"results":{"DE":{"link":"https://tmdb.test/title",
          "flatrate":[{"provider_id":8,"provider_name":"Netflix","logo_path":"/n.png"}],
          "rent":[{"provider_id":2,"provider_name":"Store","logo_path":null}]}}}
        """)
        let client = try TMDBClient(
            session: session,
            baseURL: #require(URL(string: "https://example.test/v1"))
        )
        let media = TMDBMediaResult(
            id: 10, mediaType: .movie, title: "Title",
            overview: "", posterPath: nil, releaseDate: nil
        )

        let de = try await client.watchProviders(for: media, region: "DE")
        let us = try await client.watchProviders(for: media, region: "US")
        #expect(de?[.flatrate].map(\.name) == ["Netflix"])
        #expect(de?[.rent].map(\.name) == ["Store"])
        #expect(us == nil)
    }

    @Test func `maps backend rate limits errors and malformed responses`() async throws {
        let limited = try TMDBClient(
            session: FixtureSession("{}", status: 429, headers: ["Retry-After": "12"]),
            baseURL: #require(URL(string: "https://example.test/v1"))
        )
        await #expect(throws: TMDBError.rateLimited(retryAfter: 12)) {
            try await limited.search(query: "x")
        }

        let malformed = try TMDBClient(
            session: FixtureSession("{"),
            baseURL: #require(URL(string: "https://example.test/v1"))
        )
        await #expect(throws: TMDBError.invalidResponse) {
            try await malformed.search(query: "x")
        }
    }

    @Test func `legacy sites decode and provider references round trip`() throws {
        let legacy = """
        [{"id":"C1A4E17B-9B32-443F-BEA8-AC1C70B31A22","name":"Netflix",
          "urlString":"https://netflix.com","createdAt":0}]
        """
        let decoded = try JSONDecoder().decode([SavedSite].self, from: Data(legacy.utf8))
        #expect(decoded.first?.tmdbProviders.isEmpty == true)

        let site = SavedSite(
            name: "Netflix",
            urlString: "https://netflix.com",
            searchURLTemplate: "https://netflix.com/search?q={query}",
            tmdbProviders: [.init(id: 8, name: "Netflix")]
        )
        let roundTrip = try JSONDecoder().decode(
            SavedSite.self,
            from: JSONEncoder().encode(site)
        )
        #expect(roundTrip.tmdbProviders == site.tmdbProviders)
        #expect(site.searchURL(for: "A & B")?.absoluteString.contains("A%20%26%20B") == true)
    }

    @Test func `single provider saves migrate and multiple selections round trip`() throws {
        let legacy = """
        {"id":"C1A4E17B-9B32-443F-BEA8-AC1C70B31A22","name":"Streaming",
        "urlString":"https://example.com","createdAt":0,
        "tmdbProvider":{"id":337,"name":"Disney Plus"}}
        """
        var site = try JSONDecoder().decode(SavedSite.self, from: Data(legacy.utf8))
        #expect(site.tmdbProviders == [TMDBProviderReference(id: 337, name: "Disney Plus")])
        site.tmdbProviders.append(TMDBProviderReference(id: 122, name: "Disney+"))
        var draft = SiteDraft(site: site)
        #expect(draft.validatedValues?.tmdbProviders == site.tmdbProviders)
        let restored = try JSONDecoder().decode(SavedSite.self, from: JSONEncoder().encode(site))
        #expect(restored.tmdbProviders == site.tmdbProviders)

        site.tmdbProviders = []
        let cleared = try JSONDecoder().decode(SavedSite.self, from: JSONEncoder().encode(site))
        #expect(cleared.tmdbProviders.isEmpty)
        draft.tmdbProviders = []
        #expect(draft.validatedValues?.tmdbProviders.isEmpty == true)
    }

    @Test(arguments: ["Disney Plus", "Disney+", "Disney +"])
    func `Disney naming variants match in both directions`(name: String) {
        let reference = TMDBProviderReference(id: 337, name: "Disney Plus")
        let alternate = TMDBProvider(id: 9999, name: name, logoPath: nil)
        #expect(reference.matches(alternate))
        #expect(TMDBProviderReference(id: 9999, name: name).matches(
            TMDBProvider(id: 337, name: "Disney Plus", logoPath: nil)
        ))
        #expect(!reference.matches(TMDBProvider(id: 508, name: "DisneyNOW", logoPath: nil)))
    }

    @Test(arguments: [[337, 122], [8, 175], [8, 1796], [9, 119], [9, 2100]])
    func `alternative provider IDs match independently of display names`(ids: [Int]) {
        let reference = TMDBProviderReference(id: ids[0], name: "Original")
        let alternate = TMDBProvider(id: ids[1], name: "Alternate", logoPath: nil)
        #expect(reference.matches(alternate))
        #expect(TMDBProviderReference(id: ids[1], name: "Alternate").matches(
            TMDBProvider(id: ids[0], name: "Original", logoPath: nil)
        ))
        #expect(!reference.matches(TMDBProvider(id: 350, name: "Apple TV", logoPath: nil)))
    }

    @Test func `prime video provider tiers match the configured site`() {
        let primeVideo = TMDBProviderReference(
            id: 9,
            name: "Amazon Prime Video"
        )

        #expect(
            primeVideo.matches(
                TMDBProvider(
                    id: 2100,
                    name: "Amazon Prime Video with Ads",
                    logoPath: nil
                )
            )
        )
        #expect(
            primeVideo.matches(
                TMDBProvider(
                    id: 9,
                    name: "Prime Video",
                    logoPath: nil
                )
            )
        )
        #expect(
            primeVideo.matches(
                TMDBProvider(
                    id: 10,
                    name: "Amazon Video",
                    logoPath: nil
                )
            )
        )
        #expect(
            !primeVideo.matches(
                TMDBProvider(
                    id: 15,
                    name: "Hulu",
                    logoPath: nil
                )
            )
        )
    }
}
