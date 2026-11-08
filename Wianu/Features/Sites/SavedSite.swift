import Foundation

struct TMDBProviderReference: Codable, Hashable, Sendable {
    let id: Int
    let name: String

    func matches(_ provider: TMDBProvider) -> Bool {
        id == provider.id
            || (providerFamily != nil
                && providerFamily == Self.family(id: provider.id, name: provider.name))
    }

    private var providerFamily: ProviderFamily? {
        Self.family(id: id, name: name)
    }

    private static func family(id: Int, name: String) -> ProviderFamily? {
        // Regional entries and subscription tiers can have different IDs.
        switch id {
        case 122, 337:
            return .disneyPlus
        case 8, 175, 1796:
            return .netflix
        case 9, 10, 119, 613, 2100:
            return .primeVideo
        default:
            break
        }

        let words =
            name
                .folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: nil
                )
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }

        if words == ["disney"] || words == ["disney", "plus"] {
            return .disneyPlus
        }
        if words == ["netflix"] || words == ["netflix", "kids"]
            || words == ["netflix", "standard", "with", "ads"]
        {
            return .netflix
        }

        // TMDB separates Prime subscription tiers from Amazon's rent/buy
        // store. We can open all of them through the same Amazon site.
        let isPrimeVideo = words.contains("prime") && words.contains("video")
        let isAmazonVideo = words == ["amazon", "video"]
        if isPrimeVideo || isAmazonVideo {
            return .primeVideo
        }

        return nil
    }

    private enum ProviderFamily {
        case primeVideo
        case disneyPlus
        case netflix
    }
}

struct SavedSite: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var urlString: String
    var searchURLTemplate: String?
    var tmdbProviders: [TMDBProviderReference]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        searchURLTemplate: String? = nil,
        tmdbProviders: [TMDBProviderReference] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.searchURLTemplate = searchURLTemplate
        self.tmdbProviders = tmdbProviders
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case urlString
        case searchURLTemplate
        case tmdbProviders
        case tmdbProvider
        case createdAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        urlString = try container.decode(String.self, forKey: .urlString)
        searchURLTemplate = try container.decodeIfPresent(String.self, forKey: .searchURLTemplate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        if let providers = try container.decodeIfPresent([TMDBProviderReference].self, forKey: .tmdbProviders) {
            tmdbProviders = providers
        } else {
            tmdbProviders = try container.decodeIfPresent(TMDBProviderReference.self, forKey: .tmdbProvider)
                .map { [$0] } ?? []
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(urlString, forKey: .urlString)
        try container.encodeIfPresent(searchURLTemplate, forKey: .searchURLTemplate)
        try container.encode(tmdbProviders, forKey: .tmdbProviders)
        try container.encode(createdAt, forKey: .createdAt)
    }

    var url: URL? {
        URL(string: urlString)
    }

    var resolvedSearchURLTemplate: String? {
        if let searchURLTemplate {
            let trimmed = searchURLTemplate.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return trimmed.isEmpty ? nil : trimmed
        }

        return StreamingSearchPreset.template(for: url)
    }

    func searchURL(for query: String) -> URL? {
        guard let resolvedSearchURLTemplate else { return nil }
        return StreamingSearchURL.makeURL(
            template: resolvedSearchURLTemplate,
            query: query
        )
    }

    var isTMDBProviderActionable: Bool {
        !tmdbProviders.isEmpty && resolvedSearchURLTemplate != nil
    }
}
