import Foundation

nonisolated enum URLNormalizer {
    private static let removableQueryNames: Set<String> = [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content"
    ]

    static func continueWatchingURL(_ url: URL) -> URL {
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )
        else {
            return url
        }

        components.fragment = nil

        if let queryItems = components.queryItems {
            let filteredItems = queryItems.filter {
                !removableQueryNames.contains($0.name.lowercased())
            }

            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        }

        return components.url ?? url
    }

    static func continueWatchingComparisonKey(for url: URL) -> String {
        if let netflixID = netflixTitleID(for: url) {
            return "netflix:\(netflixID)"
        }

        return comparisonKey(for: url)
    }

    static func continueWatchingPageURL(for url: URL) -> URL {
        guard let netflixID = netflixTitleID(for: url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }

        components.path = "/title/\(netflixID)"
        components.query = nil
        components.fragment = nil

        return components.url ?? url
    }

    private static func netflixTitleID(for url: URL) -> String? {
        guard let host = url.host()?.lowercased(), host == "netflix.com" || host.hasSuffix(".netflix.com")
        else { return nil }

        let parts = url.pathComponents
        let titleID: String? = if let index = parts.firstIndex(where: { $0 == "title" || $0 == "watch" }),
                                  parts.indices.contains(index + 1)
        {
            parts[index + 1]
        } else {
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "jbv" })?.value
        }

        guard let titleID, !titleID.isEmpty, titleID.allSatisfy(\.isNumber) else { return nil }

        return titleID
    }

    static func comparisonKey(for url: URL) -> String {
        let normalizedURL = continueWatchingURL(url)

        guard var components = URLComponents(
            url: normalizedURL,
            resolvingAgainstBaseURL: false
        )
        else {
            return normalizedURL.absoluteString
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()

        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        return components.string ?? normalizedURL.absoluteString
    }
}
