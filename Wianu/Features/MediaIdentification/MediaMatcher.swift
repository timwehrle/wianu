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
        guard complete, let year = query.year else {
            return nil
        }

        var seen = Set<MediaIdentity>()
        let candidates = candidates.filter {
            $0.id > 0 && (query.mediaType == nil || $0.mediaType == query.mediaType)
                && seen.insert($0.identity).inserted
        }

        let title = normalize(query.title)

        guard !title.isEmpty else {
            return nil
        }

        let titled = candidates.filter { candidate in
            [candidate.title, candidate.originalTitle].compactMap(\.self).contains {
                titlesAgree(query.title, $0)
            }
        }

        let exact = titled.filter { $0.year.flatMap(Int.init) == year }

        guard exact.count == 1, let match = exact.first else {
            return nil
        }

        // A film may premiere in one year and receive a wider release the next year.
        // Another film with the same title cannot be ruled out if its year is missing
        // or differs from the supplied year by only one year.
        let competitors = titled.filter { $0.identity != match.identity }

        guard competitors.allSatisfy({
            guard let distance = yearDistance($0, from: year) else {
                return false
            }

            return distance > 1
        }) else {
            return nil
        }

        return match
    }

    private static func titlesAgree(_ left: String, _ right: String) -> Bool {
        // Titles may omit punctuation, but spaces between words still matter.
        // All title variants participate in matching so that punctuation differences
        // cannot conceal another plausible candidate.
        !titleVariants(left).isDisjoint(with: titleVariants(right))
    }

    private static func titleVariants(_ title: String) -> Set<String> {
        let withoutPunctuation = String(title.unicodeScalars.filter {
            !CharacterSet.punctuationCharacters.contains($0)
        })

        return Set([normalize(title), normalize(withoutPunctuation)].filter { !$0.isEmpty })
    }

    static func yearDistance(_ candidate: TMDBMediaResult, from year: Int?) -> Int? {
        guard let year, let candidateYear = candidate.year.flatMap(Int.init) else {
            return nil
        }

        return abs(year - candidateYear)
    }
}
