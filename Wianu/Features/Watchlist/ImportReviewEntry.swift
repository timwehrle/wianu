import Foundation

struct ImportReviewEntry: Identifiable {
    var id: UUID {
        item.id
    }

    let item: WatchlistItem
    let candidates: [TMDBMediaResult]
    let classification: LetterboxdMatcher.Classification
    var selectedID: Int?
    var error: String?
    var reviewReason: String?

    var resolvedItem: WatchlistItem {
        var result = item

        if let media = candidates.first(where: { $0.id == selectedID }) {
            result.tmdbMediaType = media.mediaType
            result.tmdbID = media.id
            result.tmdbMetadata = media
        }

        return result
    }
}
