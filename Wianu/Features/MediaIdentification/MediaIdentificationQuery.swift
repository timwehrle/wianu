import Foundation

nonisolated struct MediaIdentificationQuery: Hashable, Sendable {
    let title: String
    let year: Int?
    let mediaType: TMDBMediaType?
    let movieID: Int?

    init(title: String, year: Int?, mediaType: TMDBMediaType?, movieID: Int? = nil) {
        self.title = title
        self.year = year
        self.mediaType = mediaType
        self.movieID = movieID
    }

    static func savedTitle(
        _ title: String,
        year: Int? = nil,
        mediaType: TMDBMediaType? = nil,
        url: URL? = nil
    ) -> Self {
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
            mediaType: mediaType ?? (episodeRange == nil ? nil : .tv),
            movieID: movieID(in: url)
        )
    }

    static func movieID(in url: URL?) -> Int? {
        guard let url, ["https", "http"].contains(url.scheme?.lowercased()),
              url.user() == nil, url.password() == nil
        else {
            return nil
        }

        let host = url.host()?.lowercased()
        let path = url.pathComponents.filter { $0 != "/" }

        guard path.count == 2 else {
            return nil
        }

        let rawID: String

        switch host {
        case "letterboxd.com", "www.letterboxd.com":
            guard path[0] == "tmdb" else {
                return nil
            }

            rawID = path[1]

        case "themoviedb.org", "www.themoviedb.org":
            guard path[0] == "movie" else {
                return nil
            }

            rawID = String(path[1].prefix { $0.isASCII && $0.isNumber })

            guard path[1] == rawID || path[1].hasPrefix(rawID + "-") else {
                return nil
            }

        default: return nil
        }

        guard !rawID.isEmpty, rawID.allSatisfy({ $0.isASCII && $0.isNumber }),
              let id = Int(rawID), id > 0
        else {
            return nil
        }

        return id
    }
}
