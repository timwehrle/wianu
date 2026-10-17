import Foundation

nonisolated enum MediaMatcher {
    static func normalize(_ title: String) -> String {
        title.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func match(
        _ query: MediaIdentificationQuery,
        candidates: [TMDBMediaResult],
        complete: Bool
    ) -> TMDBMediaResult? {
        guard complete else { return nil }
        var seen = Set<MediaIdentity>()
        let candidates = candidates.filter { $0.id > 0 && seen.insert($0.identity).inserted }
        let title = normalize(query.title)
        let titled = candidates.filter {
            !title.isEmpty && (normalize($0.title) == title || $0.originalTitle.map(normalize) == title)
        }
        // A sole title match tolerates missing years or a one-year premiere/release difference.
        if candidates.count == 1, let only = titled.first, (yearDistance(only, from: query.year) ?? 0) <= 1 {
            return only
        }
        let exact = titled.filter { query.year != nil && $0.year.flatMap(Int.init) == query.year }
        return exact.count == 1 ? exact.first : nil
    }

    static func yearDistance(_ candidate: TMDBMediaResult, from year: Int?) -> Int? {
        guard let year, let candidateYear = candidate.year.flatMap(Int.init) else { return nil }
        return abs(year - candidateYear)
    }
}
