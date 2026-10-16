import Foundation

struct TMDBMovieSearchResponse: Decodable {
    let page: Int
    let totalPages: Int
    let results: [TMDBMovieSearchItem]

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
    }
}

struct TMDBMovieSearchItem: Decodable {
    let media: TMDBMediaResult

    init(from decoder: Decoder) throws {
        media = try TMDBMediaResult(from: decoder, mediaType: .movie)
    }
}

struct TMDBSearchResponse: Decodable {
    let page: Int
    let totalPages: Int
    let results: [TMDBSearchItem]

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
    }
}

struct TMDBSearchItem: Decodable {
    let media: TMDBMediaResult?

    init(from decoder: Decoder) throws {
        media = try? TMDBMediaResult(from: decoder)
    }
}

struct TMDBWatchResponse: Decodable {
    let results: [String: TMDBWatchRegion]
}

struct TMDBWatchRegion: Decodable {
    let link: String?
    let flatrate: [TMDBProvider]?
    let free: [TMDBProvider]?
    let ads: [TMDBProvider]?
    let rent: [TMDBProvider]?
    let buy: [TMDBProvider]?
}

struct TMDBRegionResponse: Decodable {
    let results: [TMDBRegion]
}

struct TMDBProviderResponse: Decodable {
    let results: [TMDBProvider]
}

struct TMDBConfigurationResponse: Decodable {
    let images: Images

    struct Images: Decodable {
        let secureBaseURL: String
        let posterSizes: [String]
        let logoSizes: [String]

        enum CodingKeys: String, CodingKey {
            case secureBaseURL = "secure_base_url"
            case posterSizes = "poster_sizes"
            case logoSizes = "logo_sizes"
        }
    }
}

struct TMDBErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
