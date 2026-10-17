import Foundation
import Testing
@testable import Wianu

@Suite("Letterboxd matching")
struct LetterboxdMatcherTests {
    @Test func `classification preserves confidence rules`() {
        // swiftlint:disable:next large_tuple
        let cases: [(WatchlistItem, [TMDBMediaResult], Bool, LetterboxdMatcher.Classification)] = [
            (
                item("Dune", 1984),
                [movie(841, "Dune", "1984-12-14"), movie(438_631, "Dune", "2021-09-15")],
                true,
                .exact(841)
            ),
            (item("Dune", nil), [movie(841, "Dune", "1984")], true, .exact(841)),
            (item("Dune", 1984), [movie(438_631, "Dune", "2021")], true, .ambiguous),
            (
                item("千と千尋の神隠し", 2001),
                [movie(129, "Spirited Away", "2001", original: "千と千尋の神隠し")],
                true,
                .exact(129)
            ),
            (item("Amélie", 2001), [movie(194, "Amelie", "2001")], true, .exact(194)),
            (
                item("The Thing", 1982),
                [movie(1091, "The Thing", "1982"), movie(60935, "The Thing", "2011")],
                true,
                .exact(1091)
            ),
            (item("Same", 2000), [movie(1, "Same", "2000"), movie(2, "Same", "2000")], true, .ambiguous),
            (item("Same", 2000), [movie(1, "Same", "2000", type: .tv)], true, .unmatched),
            (item("Same", 2000), [movie(1, "Same", nil)], true, .exact(1)),
            (item("Same", 2000), [movie(1, "Same", "2000")], false, .ambiguous),
            (item("Same", 2000), [], true, .unmatched),
            (item("Enemy", 2013), [movie(181_886, "Enemy", "2014")], true, .exact(181_886)),
            (item("Enemy", 2013), [movie(181_886, "Enemy", "2014")], false, .ambiguous),
            (item("Alien", 1979), [movie(1, "Aliens", "1979")], true, .ambiguous)
        ]

        for (item, candidates, complete, expected) in cases {
            #expect(LetterboxdMatcher.classify(item, candidates: candidates, complete: complete) == expected)
        }
    }

    private func item(_ title: String, _ year: Int?) -> WatchlistItem {
        WatchlistItem(
            title: title,
            year: year,
            letterboxdURL: URL(string: "https://letterboxd.com/film/test/")!,
            addedAt: nil,
            sourceOrder: 0
        )
    }

    private func movie(
        _ id: Int,
        _ title: String,
        _ year: String?,
        original: String? = nil,
        type: TMDBMediaType = .movie
    ) -> TMDBMediaResult {
        TMDBMediaResult(
            id: id,
            mediaType: type,
            title: title,
            overview: "Overview",
            posterPath: nil,
            releaseDate: year,
            originalTitle: original
        )
    }
}
