import Foundation

struct MediaIdentificationResult: Sendable {
    let candidates: [TMDBMediaResult]
    let match: TMDBMediaResult?
    let reviewReason: String?
}

struct MediaIdentificationService {
    let client: TMDBClient

    func search(_ query: MediaIdentificationQuery) async throws -> MediaIdentificationResult {
        guard !query.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return MediaIdentificationResult(candidates: [], match: nil, reviewReason: nil)
        }
        var candidates: [TMDBMediaResult] = []
        var complete = false
        // An incomplete search cannot establish uniqueness. Keep request counts bounded.
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
        let focused = MediaMatcher.match(query, candidates: candidates, complete: complete)
        // Enemy demonstrates why a lower-ranked title/year match needs confirmation.
        let lowerRanked = focused != nil && focused?.identity != candidates.first?.identity
        var reason = reviewReason(candidates: candidates, complete: complete, lowerRanked: lowerRanked)
        if query.mediaType == .movie, query.year != nil, candidates.isEmpty || !complete || lowerRanked {
            let wasEmpty = candidates.isEmpty && complete
            let fallback = try await client.searchMovies(query: query.title, year: nil)
            candidates.append(contentsOf: fallback.results)
            complete = wasEmpty && fallback.page >= fallback.totalPages
                && Set(fallback.results.map(\.identity)).count == 1
            reason = reason
                ?? "No film was found for the supplied year. Confirm a suggestion or keep the original entry."
        } else if lowerRanked {
            complete = false
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
            reviewReason: match == nil ? reason : nil
        )
    }

    private func searchPage(_ query: MediaIdentificationQuery, page: Int) async throws -> TMDBSearchPage {
        if query.mediaType == .movie {
            return try await client.searchMovies(query: query.title, year: query.year, page: page)
        }
        return try await client.search(query: query.title, page: page, paced: true)
    }

    private func reviewReason(candidates: [TMDBMediaResult], complete: Bool, lowerRanked: Bool) -> String? {
        if lowerRanked {
            return "The title and year match a lower-ranked result. Confirm the intended film or show."
        }
        if !complete {
            return "The search has more results than could be checked."
        }
        switch candidates.count {
        case 0: return nil
        case 1: return "The title or release year differs. Confirm the intended film or show."
        default: return "Several films or shows may match. Confirm the title and release year."
        }
    }
}
