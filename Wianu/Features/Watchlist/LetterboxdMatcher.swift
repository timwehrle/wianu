import Foundation

enum LetterboxdMatcher {
    enum Classification: Equatable {
        case exact(Int)
        case ambiguous
        case unmatched

        var matchedID: Int? {
            guard case let .exact(id) = self else {
                return nil
            }

            return id
        }
    }

    static func classify(
        _ item: WatchlistItem,
        candidates: [TMDBMediaResult],
        complete: Bool = true
    ) -> Classification {
        let movies = candidates.filter { $0.mediaType == .movie && $0.id > 0 }

        guard !movies.isEmpty else {
            return .unmatched
        }

        let query = MediaIdentificationQuery(
            title: item.title, year: item.year, mediaType: .movie,
            movieID: MediaIdentificationQuery.movieID(in: item.url)
        )

        guard let match = MediaMatcher.match(query, candidates: movies, complete: complete) else {
            return .ambiguous
        }

        return .exact(match.id)
    }

    static func search(_ item: WatchlistItem, client: TMDBClient) async throws -> ImportReviewEntry {
        let query = MediaIdentificationQuery(
            title: item.title, year: item.year, mediaType: .movie,
            movieID: MediaIdentificationQuery.movieID(in: item.url)
        )
        let result = try await MediaIdentificationService(client: client).search(query)
        let classification: Classification = if let match = result.match {
            .exact(match.id)
        } else {
            result.candidates.isEmpty ? .unmatched : .ambiguous
        }

        return ImportReviewEntry(
            item: item,
            candidates: result.candidates,
            classification: classification,
            selectedID: result.match?.id,
            reviewReason: result.reviewReason
        )
    }
}
