import Foundation

nonisolated struct MediaIdentificationQuery: Hashable, Sendable {
    let title: String
    let year: Int?
    let mediaType: TMDBMediaType?

    static func savedTitle(_ title: String, year: Int? = nil, mediaType: TMDBMediaType? = nil) -> Self {
        let episodePattern = #"(?i)\s*[-–—:|]?\s*(?:s\d{1,2}\s*e\d{1,3}|season\s+\d+\s*[,\-:]?\s*episode\s+\d+)\b.*$"#
        var cleaned = title
        let episodeRange = cleaned.range(of: episodePattern, options: .regularExpression)
        if let episodeRange {
            cleaned.removeSubrange(episodeRange)
        }
        var releaseYear = year
        if let range = cleaned.range(of: #"[\(\[]((?:18|19|20|21)\d{2})[\)\]]"#, options: .regularExpression) {
            releaseYear = releaseYear ?? Int(cleaned[range].dropFirst().dropLast())
            cleaned.removeSubrange(range)
        }
        return Self(
            title: cleaned.trimmingCharacters(in: .whitespacesAndNewlines),
            year: releaseYear,
            mediaType: mediaType ?? (episodeRange == nil ? nil : .tv)
        )
    }
}
