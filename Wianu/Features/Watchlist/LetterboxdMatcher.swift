import Foundation

enum LetterboxdMatcher {
    enum Classification: Equatable {
        case exact(Int)
        case ambiguous
        case unmatched

        var matchedID: Int? {
            guard case let .exact(id) = self else { return nil }

            return id
        }
    }

    nonisolated static func normalize(_ title: String) -> String {
        title.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func classify(
        _ item: WatchlistItem,
        candidates: [TMDBMediaResult],
        complete: Bool = true
    ) -> Classification {
        let movies = candidates.filter { $0.mediaType == .movie && $0.id > 0 }

        guard !movies.isEmpty else { return .unmatched }

        let title = normalize(item.title)
        let titled = movies.filter {
            !title.isEmpty && (normalize($0.title) == title
                || $0.originalTitle.map(normalize) == title)
        }

        // A sole exact-title result may differ by one year because of premier and theatrical dates or whatever.
        // Missing years are also accepted here.
        if complete, Set(movies.map(\.id)).count == 1, let only = titled.first {
            if (yearDistance(only, from: item) ?? 0) <= 1 {
                return .exact(only.id)
            }
        }

        let exact = titled.filter {
            item.year != nil && $0.year.flatMap(Int.init) == item.year
        }

        let ids = Set(exact.map(\.id))

        if complete, ids.count == 1, let id = ids.first {
            return .exact(id)
        }

        return .ambiguous
    }

    static func search(_ item: WatchlistItem, client: TMDBClient) async throws -> ImportReviewEntry {
        var candidates: [TMDBMediaResult] = []
        var complete = false

        for page in 1 ... 5 {
            try Task.checkCancellation()
            let response = try await client.searchMovies(query: item.title, year: item.year, page: page)
            candidates.append(contentsOf: response.results)

            if response.page >= response.totalPages {
                complete = true
                break
            }
        }

        let focused = classify(item, candidates: candidates, complete: complete)
        let lowerRankedMatch = focused.matchedID != nil && focused.matchedID != candidates.first?.id

        var reviewReason: String?

        if lowerRankedMatch {
            reviewReason = "The title and year match a lower-ranked result. Confirm the intended film."
        } else if focused == .ambiguous, complete {
            reviewReason = Set(candidates.map(\.id)).count == 1
                ? "The result has a different title or release year. Confirm the intended film."
                : "Several films may match this entry. Confirm the title and release year."
        } else if !complete {
            reviewReason = "The search has more results than could be checked."
        }

        if item.year != nil, focused == .unmatched || !complete || lowerRankedMatch {
            let hadNoCandidates = candidates.isEmpty && complete
            let fallback = try await client.searchMovies(query: item.title, year: nil)

            candidates.append(contentsOf: fallback.results)
            complete = hadNoCandidates && fallback.page >= fallback.totalPages
                && Set(fallback.results.map(\.id)).count == 1
            reviewReason = reviewReason
                ?? "No film was found for the supplied year. Confirm a suggestion or keep the original entry."
        }

        var seen = Set<Int>()

        candidates = candidates.filter { seen.insert($0.id).inserted }
        candidates = orderedCandidates(candidates, for: item)

        let classification = classify(item, candidates: candidates, complete: complete)

        return ImportReviewEntry(
            item: item,
            candidates: candidates,
            classification: classification,
            selectedID: classification.matchedID,
            reviewReason: classification.matchedID == nil ? reviewReason : nil
        )
    }

    private static func orderedCandidates(
        _ candidates: [TMDBMediaResult],
        for item: WatchlistItem
    ) -> [TMDBMediaResult] {
        candidates.sorted {
            let leftDistance = yearDistance($0, from: item) ?? Int.max
            let rightDistance = yearDistance($1, from: item) ?? Int.max

            if leftDistance != rightDistance {
                return leftDistance < rightDistance
            }

            return $0.id < $1.id
        }
    }

    private static func yearDistance(_ candidate: TMDBMediaResult, from item: WatchlistItem) -> Int? {
        guard let year = item.year, let candidateYear = candidate.year.flatMap(Int.init) else { return nil }

        return abs(year - candidateYear)
    }
}
