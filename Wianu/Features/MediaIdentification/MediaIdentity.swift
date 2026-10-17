import Foundation

nonisolated struct MediaIdentity: Codable, Hashable, Sendable {
    let id: Int
    let mediaType: TMDBMediaType
}

extension TMDBMediaResult {
    nonisolated var identity: MediaIdentity {
        MediaIdentity(id: id, mediaType: mediaType)
    }
}

nonisolated enum MediaIdentificationTarget: Hashable, Identifiable {
    case watchlist(UUID)
    case continueWatching(UUID)

    var id: Self {
        self
    }
}
