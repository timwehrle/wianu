import Foundation

nonisolated struct WatchlistItem: Identifiable, Codable, Hashable, Sendable {
    enum Source: String, Codable, Hashable, Sendable {
        case custom
        case letterboxd
    }

    var tmdbID: Int?
    var tmdbMetadata: TMDBMediaResult?
    let id: UUID
    private(set) var title: String
    private(set) var year: Int?
    private(set) var url: URL?
    let addedAt: Date?
    private(set) var sourceOrder: Int
    let source: Source

    init(
        id: UUID = UUID(),
        title: String,
        year: Int?,
        url: URL?,
        addedAt: Date?,
        sourceOrder: Int,
        source: Source,
        tmdbID: Int? = nil,
        tmdbMetadata: TMDBMediaResult? = nil
    ) {
        self.tmdbID = tmdbID
        self.tmdbMetadata = tmdbMetadata
        self.id = id
        self.title = title
        self.year = year
        self.url = url
        self.addedAt = addedAt
        self.sourceOrder = sourceOrder
        self.source = source
    }

    func updating(title: String, year: Int?, url: URL?) -> Self {
        var item = self
        item.title = title
        item.year = year
        item.url = url

        return item
    }

    func withSourceOrder(_ sourceOrder: Int) -> Self {
        var item = self
        item.sourceOrder = sourceOrder

        return item
    }

    init(
        id: UUID = UUID(),
        title: String,
        year: Int?,
        letterboxdURL: URL,
        addedAt: Date?,
        sourceOrder: Int
    ) {
        self.init(
            id: id,
            title: title,
            year: year,
            url: letterboxdURL,
            addedAt: addedAt,
            sourceOrder: sourceOrder,
            source: .letterboxd
        )
    }

    private enum CodingKeys: String, CodingKey {
        case tmdbID, tmdbMetadata
        case id, title, year, url, letterboxdURL, addedAt, sourceOrder, source
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tmdbID = try values.decodeIfPresent(Int.self, forKey: .tmdbID)
        tmdbMetadata = try values.decodeIfPresent(TMDBMediaResult.self, forKey: .tmdbMetadata)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        year = try values.decodeIfPresent(Int.self, forKey: .year)
        url = try values.decodeIfPresent(URL.self, forKey: .url)
            ?? values.decodeIfPresent(URL.self, forKey: .letterboxdURL)
        addedAt = try values.decodeIfPresent(Date.self, forKey: .addedAt)
        sourceOrder = try values.decode(Int.self, forKey: .sourceOrder)
        source = try values.decodeIfPresent(Source.self, forKey: .source)
            ?? .letterboxd
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(tmdbID, forKey: .tmdbID)
        try values.encodeIfPresent(tmdbMetadata, forKey: .tmdbMetadata)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encodeIfPresent(year, forKey: .year)
        try values.encodeIfPresent(url, forKey: .url)
        try values.encodeIfPresent(addedAt, forKey: .addedAt)
        try values.encode(sourceOrder, forKey: .sourceOrder)
        try values.encode(source, forKey: .source)
    }
}
