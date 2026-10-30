import Foundation

struct MediaIdentificationResult: Sendable {
    let candidates: [TMDBMediaResult]
    let match: TMDBMediaResult?
    let reviewReason: String?
}

struct MediaIdentificationService {
    let client: TMDBClient

    func search(_ query: MediaIdentificationQuery) async throws -> MediaIdentificationResult {
        if let id = query.movieID, query.mediaType != .tv {
            try Task.checkCancellation()

            let movie = try await client.movie(id: id)

            return MediaIdentificationResult(candidates: [movie], match: movie, reviewReason: nil)
        }

        guard !query.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return MediaIdentificationResult(candidates: [], match: nil, reviewReason: nil)
        }

        // Searching without a year filter keeps remakes and films with different
        // premiere and release years available for comparison.
        var candidates: [TMDBMediaResult] = []
        var complete = false

        // Only a complete search can establish that a match is unique.
        for page in 1 ... 5 {
            try Task.checkCancellation()

            let response = try await searchPage(query, page: page)
            let filtered = response.results.filter { query.mediaType == nil || $0.mediaType == query.mediaType }

            candidates.append(contentsOf: filtered)

            if response.page >= response.totalPages {
                complete = true
                break
            }
        }

        var seen = Set<MediaIdentity>()
        candidates = candidates.filter { $0.id > 0 && seen.insert($0.identity).inserted }

        let match = MediaMatcher.match(query, candidates: candidates, complete: complete)

        candidates.sort {
            let left = MediaMatcher.yearDistance($0, from: query.year) ?? Int.max
            let right = MediaMatcher.yearDistance($1, from: query.year) ?? Int.max

            if left != right {
                return left < right
            }

            if $0.id != $1.id {
                return $0.id < $1.id
            }

            return $0.mediaType.rawValue < $1.mediaType.rawValue
        }

        return MediaIdentificationResult(
            candidates: candidates,
            match: match,
            reviewReason: match == nil ? reviewReason(query: query, candidates: candidates, complete: complete) : nil
        )
    }

    private func searchPage(_ query: MediaIdentificationQuery, page: Int) async throws -> TMDBSearchPage {
        if query.mediaType == .movie {
            return try await client.searchMovies(query: query.title, year: nil, page: page)
        }

        return try await client.search(query: query.title, page: page, paced: true)
    }

    private func reviewReason(
        query: MediaIdentificationQuery,
        candidates: [TMDBMediaResult],
        complete: Bool
    ) -> String? {
        if !complete {
            return "The search has more results than could be checked."
        }

        guard !candidates.isEmpty else {
            return nil
        }

        if query.year == nil {
            return "The saved release year is unknown. Confirm the intended film or show."
        }

        return "Confirm the intended title and release year, or keep the original entry without a match."
    }
}
