import Foundation

nonisolated enum TMDBMediaType: String, Codable, Sendable {
    case movie
    case tv
}

nonisolated struct TMDBMediaResult: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let mediaType: TMDBMediaType
    let title: String
    let originalTitle: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?

    var year: String? {
        releaseDate?.split(separator: "-").first.map(String.init)
    }

    var letterboxdURL: URL? {
        guard mediaType == .movie else { return nil }

        return URL(string: "https://letterboxd.com/tmdb/\(id)")
    }

    init(
        id: Int,
        mediaType: TMDBMediaType,
        title: String,
        overview: String,
        posterPath: String?,
        releaseDate: String?,
        originalTitle: String? = nil,
        backdropPath: String? = nil
    ) {
        self.backdropPath = backdropPath
        self.originalTitle = originalTitle
        self.id = id
        self.mediaType = mediaType
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, overview
        case originalTitle = "original_title"
        case originalName = "original_name"
        case mediaType = "media_type"
        case movieTitle = "title"
        case tvTitle = "name"
        case backdropPath = "backdrop_path"
        case posterPath = "poster_path"
        case movieDate = "release_date"
        case tvDate = "first_air_date"
    }

    init(from decoder: Decoder) throws {
        try self.init(from: decoder, mediaType: nil)
    }

    init(from decoder: Decoder, mediaType knownType: TMDBMediaType?) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        originalTitle = try values.decodeIfPresent(String.self, forKey: .originalTitle)
            ?? values.decodeIfPresent(String.self, forKey: .originalName)
        backdropPath = try values.decodeIfPresent(String.self, forKey: .backdropPath)
        id = try values.decode(Int.self, forKey: .id)

        if let knownType {
            mediaType = knownType
        } else {
            mediaType = try values.decode(TMDBMediaType.self, forKey: .mediaType)
        }

        title =
            try values.decodeIfPresent(String.self, forKey: .movieTitle)
                ?? values.decode(String.self, forKey: .tvTitle)
        overview =
            try values.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try values.decodeIfPresent(
            String.self,
            forKey: .posterPath
        )
        releaseDate =
            try values.decodeIfPresent(String.self, forKey: .movieDate)
                ?? values.decodeIfPresent(String.self, forKey: .tvDate)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(originalTitle, forKey: mediaType == .movie ? .originalTitle : .originalName)
        try values.encode(id, forKey: .id)
        try values.encode(mediaType, forKey: .mediaType)
        try values.encode(overview, forKey: .overview)
        try values.encodeIfPresent(posterPath, forKey: .posterPath)
        try values.encodeIfPresent(backdropPath, forKey: .backdropPath)

        if mediaType == .movie {
            try values.encode(title, forKey: .movieTitle)
            try values.encodeIfPresent(releaseDate, forKey: .movieDate)
        } else {
            try values.encode(title, forKey: .tvTitle)
            try values.encodeIfPresent(releaseDate, forKey: .tvDate)
        }
    }
}

struct TMDBProvider: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?

    private enum CodingKeys: String, CodingKey {
        case id = "provider_id"
        case name = "provider_name"
        case logoPath = "logo_path"
    }
}

struct TMDBRegion: Identifiable, Codable, Hashable, Sendable {
    let isoCode: String
    let englishName: String
    let nativeName: String

    var id: String {
        isoCode
    }

    var displayName: String {
        nativeName.isEmpty ? englishName : nativeName
    }

    private enum CodingKeys: String, CodingKey {
        case isoCode = "iso_3166_1"
        case englishName = "english_name"
        case nativeName = "native_name"
    }
}

enum TMDBOfferType: String, CaseIterable, Identifiable, Sendable {
    case flatrate = "Subscription"
    case free = "Free"
    case ads = "Ads"
    case rent = "Rent"
    case buy = "Buy"
    var id: String {
        rawValue
    }
}

struct TMDBWatchAvailability: Sendable {
    let link: URL?
    let groups: [TMDBOfferType: [TMDBProvider]]

    subscript(_ type: TMDBOfferType) -> [TMDBProvider] {
        groups[type] ?? []
    }
}

struct TMDBSearchPage: Sendable {
    let page: Int
    let totalPages: Int
    let results: [TMDBMediaResult]
}

struct TMDBImageConfiguration: Sendable {
    let secureBaseURL: URL
    let posterSize: String
    let logoSize: String

    func posterURL(path: String?) -> URL? {
        imageURL(path: path, size: posterSize)
    }

    func backdropURL(path: String?) -> URL? {
        imageURL(path: path, size: "w1280")
    }

    func logoURL(path: String?) -> URL? {
        imageURL(path: path, size: logoSize)
    }

    private func imageURL(path: String?, size: String) -> URL? {
        guard let path else { return nil }

        return secureBaseURL.appending(path: size).appending(path: path)
    }
}
