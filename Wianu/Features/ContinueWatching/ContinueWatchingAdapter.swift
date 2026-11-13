import Foundation

enum ContinueWatchingService: String, CaseIterable, Identifiable, Sendable {
    case hboMax, netflix, primeVideo, disneyPlus, appleTV

    var id: Self {
        self
    }
}

struct ContinueWatchingAdapter: Identifiable {
    let id: ContinueWatchingService
    let name: String
    let hosts: [String]
    let homePath: String

    static let hboMax = Self(id: .hboMax, name: "HBO Max", hosts: ["hbomax.com"], homePath: "/")
    static let netflix = Self(id: .netflix, name: "Netflix", hosts: ["netflix.com"], homePath: "/browse")
    static let primeVideo = Self(
        id: .primeVideo, name: "Prime Video",
        hosts: ["primevideo.com", "amazon.com", "amazon.de", "amazon.co.uk"], homePath: "/"
    )
    static let disneyPlus = Self(id: .disneyPlus, name: "Disney+", hosts: ["disneyplus.com"], homePath: "/home")
    static let appleTV = Self(id: .appleTV, name: "Apple TV", hosts: ["tv.apple.com"], homePath: "/")
    static let all: [Self] = [.hboMax, .netflix, .primeVideo, .disneyPlus, .appleTV]

    func matches(_ url: URL?) -> Bool {
        guard let host = url?.host()?.lowercased() else { return false }

        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    func refreshURL(for siteURL: URL) -> URL? {
        guard matches(siteURL), var components = URLComponents(url: siteURL, resolvingAgainstBaseURL: false)
        else { return nil }

        components.path = id == .primeVideo && !(siteURL.host()?.hasSuffix("primevideo.com") ?? false)
            ? "/gp/video/storefront" : homePath
        components.query = nil
        components.fragment = nil

        return components.url
    }

    func playbackURL(id contentID: String, supplied: URL?) -> URL? {
        guard !contentID.isEmpty, contentID.count <= 150,
              contentID.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
        else { return nil }

        if id == .hboMax {
            guard UUID(uuidString: contentID) != nil else { return nil }

            return URL(string: "https://www.hbomax.com/video/watch/" + contentID.lowercased())
        }

        guard let supplied, matches(supplied), supplied.scheme == "https",
              supplied.user == nil, supplied.password == nil else { return nil }

        switch id {
        case .netflix:
            let previewID = URLComponents(url: supplied, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "jbv" }?.value
            let matchesPath = ["/watch/" + contentID, "/title/" + contentID].contains(supplied.path)
            let matchesPreview = supplied.path == "/browse" && previewID == contentID

            guard contentID.allSatisfy(\.isNumber), matchesPath || matchesPreview else { return nil }
        case .primeVideo:
            guard supplied.path.contains("/detail/") else { return nil }
        case .disneyPlus:
            guard supplied.path.contains("/play/") || supplied.path.contains("/video/")
                || supplied.path.contains("/browse/entity-") else { return nil }
        case .appleTV:
            guard supplied.path.contains("/episode/") || supplied.path.contains("/movie/")
                || supplied.path.contains("/show/") else { return nil }
        case .hboMax:
            return nil
        }

        return supplied
    }

    var observerScript: String {
        ContinueWatchingScripts.source(for: self)
    }
}
