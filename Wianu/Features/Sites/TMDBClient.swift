import Foundation

enum TMDBError: LocalizedError, Equatable {
    case invalidResponse
    case rateLimited(retryAfter: TimeInterval?)
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The movie service returned an unreadable response."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                "TMDB is busy. Try again in \(Int(retryAfter)) seconds."
            } else {
                "TMDB is busy. Please try again shortly."
            }
        case let .server(_, message):
            message ?? "The movie service could not complete the request."
        }
    }
}

nonisolated protocol TMDBSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: TMDBSession {}

struct TMDBClient: Sendable {
    private let session: any TMDBSession
    private let baseURL: URL
    private let language: String

    init(
        session: any TMDBSession = URLSession.shared,
        baseURL: URL = URL(string: "https://api.wianu.com/v1")!,
        language: String = Locale.current.identifier
    ) {
        self.session = session
        self.baseURL = baseURL
        self.language = language.replacingOccurrences(of: "_", with: "-")
    }

    func weeklyMovies() async throws -> [TMDBMediaResult] {
        let archive: WeeklyArchiveResponse = try await request(path: "weekly")
        var movies: [TMDBMediaResult] = []
        for id in archive.weeks.first?.movieIds ?? [] {
            try Task.checkCancellation()
            let movie: WeeklyMovieResponse = try await request(path: "movie/\(id)")
            movies.append(TMDBMediaResult(
                id: movie.id,
                mediaType: .movie,
                title: movie.title,
                overview: movie.overview,
                posterPath: movie.posterPath,
                releaseDate: movie.releaseDate,
                backdropPath: movie.backdropPath
            ))
        }
        return movies
    }

    func search(query: String, page: Int = 1, paced: Bool = false) async throws -> TMDBSearchPage {
        let parameters = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "language", value: language)
        ]
        let response: TMDBSearchResponse = if paced {
            try await searchRequest(path: "search/multi", query: parameters)
        } else {
            try await request(path: "search/multi", query: parameters)
        }

        return TMDBSearchPage(
            page: response.page,
            totalPages: response.totalPages,
            results: response.results.compactMap(\.media)
        )
    }

    func searchMovies(query: String, year: Int?, page: Int = 1) async throws -> TMDBSearchPage {
        var parameters = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ]

        if let year, (1800 ... 2200).contains(year) {
            parameters.append(URLQueryItem(name: "year", value: String(year)))
        }

        let response: TMDBMovieSearchResponse = try await searchRequest(path: "search/movie", query: parameters)
        return TMDBSearchPage(
            page: response.page,
            totalPages: response.totalPages,
            results: response.results.map(\.media)
        )
    }

    private func searchRequest<Response: Decodable>(path: String, query: [URLQueryItem]) async throws -> Response {
        for attempt in 0 ... 2 {
            try await Task.sleep(for: .milliseconds(300))
            do {
                return try await request(path: path, query: query)
            } catch let error as TMDBError {
                guard attempt < 2 else { throw error }
                let delay: TimeInterval
                switch error {
                case let .rateLimited(retryAfter):
                    delay = max(retryAfter ?? Double(attempt + 1), 1)
                    guard delay <= 30 else { throw error }
                case let .server(status, _) where status >= 500:
                    delay = Double(attempt + 1)
                default: throw error
                }
                try await Task.sleep(for: .seconds(delay))
            }
        }
        throw TMDBError.invalidResponse
    }

    func watchProviders(
        for media: TMDBMediaResult,
        region: String
    ) async throws -> TMDBWatchAvailability? {
        let response: TMDBWatchResponse = try await request(
            path: "\(media.mediaType.rawValue)/\(media.id)/watch/providers"
        )

        guard let value = response.results[region.uppercased()] else {
            return nil
        }

        return TMDBWatchAvailability(
            link: value.link.flatMap(URL.init(string:)),
            groups: [
                .flatrate: value.flatrate ?? [],
                .free: value.free ?? [],
                .ads: value.ads ?? [],
                .rent: value.rent ?? [],
                .buy: value.buy ?? []
            ]
        )
    }

    func regions() async throws -> [TMDBRegion] {
        let response: TMDBRegionResponse = try await request(
            path: "watch/providers/regions"
        )

        return response.results.sorted {
            $0.displayName.localizedStandardCompare($1.displayName)
                == .orderedAscending
        }
    }

    func providers() async throws -> [TMDBProvider] {
        let movies: TMDBProviderResponse = try await request(
            path: "watch/providers/movie",
            query: [URLQueryItem(name: "language", value: language)]
        )
        let shows: TMDBProviderResponse = try await request(
            path: "watch/providers/tv",
            query: [URLQueryItem(name: "language", value: language)]
        )
        let combined = movies.results + shows.results

        return Dictionary(grouping: combined, by: \.id)
            .compactMap(\.value.first)
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    func imageConfiguration() async throws -> TMDBImageConfiguration {
        let response: TMDBConfigurationResponse = try await request(
            path: "configuration"
        )

        guard let url = URL(string: response.images.secureBaseURL),
              let posterSize = preferredSize(
                  response.images.posterSizes,
                  target: "w342"
              ),
              let logoSize = preferredSize(
                  response.images.logoSizes,
                  target: "w92"
              )
        else { throw TMDBError.invalidResponse }

        return TMDBImageConfiguration(
            secureBaseURL: url,
            posterSize: posterSize,
            logoSize: logoSize
        )
    }

    private func preferredSize(_ sizes: [String], target: String) -> String? {
        sizes.contains(target) ? target : sizes.last
    }

    private func request<Response: Decodable>(
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> Response {
        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else { throw TMDBError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let message = try? JSONDecoder().decode(
                TMDBErrorResponse.self,
                from: data
            ).error.message

            switch http.statusCode {
            case 429:
                throw TMDBError.rateLimited(
                    retryAfter: http.value(forHTTPHeaderField: "Retry-After")
                        .flatMap(TimeInterval.init)
                )
            default:
                throw TMDBError.server(
                    statusCode: http.statusCode,
                    message: message
                )
            }
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw TMDBError.invalidResponse
        }
    }
}
