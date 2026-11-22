import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Browser navigation router")
struct BrowserNavigationRouterTests {
    @Test func `HTTP navigation is retried securely and downgrade loops are blocked`() throws {
        let router = BrowserNavigationRouter()
        let url = try #require(URL(string: "http://example.com:80/home?q=movie#section"))
        let request = URLRequest(url: url)
        try router.openDestination(#require(URL(string: "https://example.com")))
        let original = try #require(router.request)
        router.loadDidBegin(original.id)
        #expect(router.upgradeInsecureNavigation(request))
        let queued = try #require(router.request)
        guard case let .load(secureRequest, _) = queued.action else {
            Issue.record("Expected an HTTPS load")
            return
        }
        #expect(secureRequest.url?.absoluteString == "https://example.com/home?q=movie#section")
        router.loadDidEnd(original.id)
        #expect(!router.upgradeInsecureNavigation(request))
        router.loadDidBegin(queued.id)
        #expect(!router.upgradeInsecureNavigation(request))
        #expect(router.request?.id == queued.id)
        router.loadDidEnd(queued.id)
        #expect(router.upgradeInsecureNavigation(request))
    }

    @Test func `HTTPS upgrades preserve HEAD requests and reject credentials and POST`() throws {
        var request = try URLRequest(url: #require(URL(string: "http://example.com:8080/path")))
        request.httpMethod = "HEAD"
        request.setValue("value", forHTTPHeaderField: "X-Test")
        let upgraded = try #require(BrowserURLPolicy.upgradingToHTTPS(request))
        #expect(upgraded.httpMethod == "HEAD")
        #expect(upgraded.value(forHTTPHeaderField: "X-Test") == "value")
        #expect(upgraded.url?.port == 8080)
        request.httpMethod = "POST"
        #expect(BrowserURLPolicy.upgradingToHTTPS(request) == nil)
        request = try URLRequest(url: #require(URL(string: "http://user:password@example.com")))
        #expect(BrowserURLPolicy.upgradingToHTTPS(request) == nil)
        request = try URLRequest(url: #require(URL(string: "https://example.com")))
        #expect(BrowserURLPolicy.upgradingToHTTPS(request) == nil)
    }

    @Test func `tracks a programmatic load through its policy phase`() throws {
        let router = BrowserNavigationRouter()
        try router.openDestination(#require(URL(string: "https://example.com")))
        let request = try #require(router.request)

        #expect(!router.isPerformingLoad)

        router.loadDidBegin(request.id)
        #expect(router.isPerformingLoad)

        router.loadDidEnd(request.id)
        #expect(!router.isPerformingLoad)
    }

    @Test func `stale completion cannot clear a replacement load`() throws {
        let router = BrowserNavigationRouter()
        try router.openDestination(#require(URL(string: "https://example.com")))
        let firstRequest = try #require(router.request)
        router.loadDidBegin(firstRequest.id)

        try router.openDestination(#require(URL(string: "https://example.org")))
        let replacementRequest = try #require(router.request)
        router.loadDidBegin(replacementRequest.id)

        router.loadDidEnd(firstRequest.id)
        #expect(router.isPerformingLoad)

        router.loadDidEnd(replacementRequest.id)
        #expect(!router.isPerformingLoad)
    }

    @Test func `only secure credential-free web URLs are accepted`() {
        #expect(
            BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "https://example.com/watch?id=1")
            )
        )
        #expect(
            !BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "http://example.com")
            )
        )
        #expect(
            !BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "file:///tmp/movie")
            )
        )
        #expect(
            !BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "https://user:secret@example.com")
            )
        )
    }

    @Test func `router preserves but blocks insecure legacy destinations`() throws {
        let router = BrowserNavigationRouter()
        let accepted = try router.openDestination(
            #require(URL(string: "http://example.com"))
        )

        #expect(!accepted)
        #expect(router.request == nil)
        #expect(router.blockedNavigationMessage != nil)
    }

    @Test func `site and search inputs require HTTPS`() {
        #expect(
            SiteDraft(name: "Secure", address: "https://example.com")
                .siteURLIsValid
        )
        #expect(
            !SiteDraft(name: "Legacy", address: "http://example.com")
                .siteURLIsValid
        )
        #expect(
            StreamingSearchURL.isValidTemplate(
                "https://example.com/search?q={query}"
            )
        )
        #expect(
            !StreamingSearchURL.isValidTemplate(
                "http://example.com/search?q={query}"
            )
        )
    }

    @Test func `Letterboxd imports upgrade HTTP and enforce size limits`() throws {
        let csv = "Name,Letterboxd URI\nMovie,http://letterboxd.com/film/movie/\n"
        let result = try LetterboxdWatchlistImporter.importItems(
            from: Data(csv.utf8)
        )
        #expect(result.items.first?.url?.scheme == "https")

        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try Data(csv.utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: LetterboxdWatchlistImportError.self) {
            try LetterboxdWatchlistImporter.importItems(
                contentsOf: fileURL,
                maximumBytes: 4
            )
        }
    }
}

@MainActor
@Suite("Browser session retention")
struct BrowserSessionRetentionTests {
    @Test func `retains recent sites and evicts the least recently used`() throws {
        let sessions = BrowserSessions(continueWatchingQueues: [])
        let sites = (1 ... 4).map { SavedSite(name: "Site \($0)", urlString: "https://site\($0).invalid") }

        func open(_ site: SavedSite, intent: AppModel.NavigationRequest.Intent = .restoreSite) throws {
            let url = try #require(site.url)
            sessions.open(.init(url: url, site: site, intent: intent))
        }

        try open(sites[0])
        let first = try #require(sessions.active)
        let originalRequest = first.router.request?.id
        try open(sites[1])
        let second = sessions.active
        try open(sites[2])
        try open(sites[0])
        #expect(sessions.active === first)
        #expect(first.router.request?.id == originalRequest)

        try open(sites[3])
        try open(sites[1])
        #expect(sessions.active !== second)
        sessions.cancelNavigation()
    }

    @Test func `explicit destinations navigate in a retained session`() throws {
        let sessions = BrowserSessions(continueWatchingQueues: [])
        let site = SavedSite(name: "Site", urlString: "https://site.invalid")
        let home = try #require(site.url)
        let destination = try #require(URL(string: "https://site.invalid/movie"))
        sessions.open(.init(url: home, site: site, intent: .restoreSite))
        let session = try #require(sessions.active)
        let originalRequest = session.router.request?.id
        sessions.open(.init(url: destination, site: site, intent: .navigate))
        #expect(sessions.active === session)
        #expect(session.router.request?.id != originalRequest)
        sessions.cancelNavigation()
    }

    @Test func `opening a retained site after removal does not reuse it for a new site`() throws {
        let sessions = BrowserSessions(continueWatchingQueues: [])
        let first = SavedSite(name: "First", urlString: "https://first.invalid")
        let second = SavedSite(name: "Second", urlString: "https://second.invalid")
        let third = SavedSite(name: "Third", urlString: "https://third.invalid")

        func open(_ site: SavedSite) throws {
            let url = try #require(site.url)
            sessions.open(.init(url: url, site: site, intent: .restoreSite))
        }

        try open(first)
        let retained = sessions.active
        try open(second)
        sessions.removeChangedSites([first, third])
        try open(first)
        #expect(sessions.active === retained)
        try open(third)
        #expect(sessions.active !== retained)
        sessions.cancelNavigation()
    }

    @Test func `removed sites release their active session`() throws {
        let sessions = BrowserSessions(continueWatchingQueues: [])
        let site = SavedSite(name: "Site", urlString: "https://site.invalid")
        let url = try #require(site.url)
        #expect(sessions.active == nil)
        sessions.open(.init(url: url, site: site, intent: .restoreSite))
        #expect(sessions.active != nil)
        sessions.removeChangedSites([])
        #expect(sessions.active == nil)
        sessions.cancelNavigation()
    }
}
