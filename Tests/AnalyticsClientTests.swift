import Foundation
import Testing
@testable import Wianu

private actor AnalyticsFixtureSession: AnalyticsSession {
    private(set) var requests: [URLRequest] = []

    // Required to be async by AnalyticsSession.
    // swiftlint:disable:next async_without_await
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}

@Suite("Analytics client")
struct AnalyticsClientTests {
    @Test(arguments: [AnalyticsEvent.searchOpened, .siteOpened])
    func `sends privacy minimal Umami event`(event: AnalyticsEvent) async throws {
        let defaults = try #require(UserDefaults(
            suiteName: "AnalyticsClientTests.send.\(UUID().uuidString)"
        ))
        let session = AnalyticsFixtureSession()
        let client = AnalyticsClient(
            session: session,
            endpoint: URL(string: "https://analytics.example/api/send"),
            websiteID: "website-id",
            userDefaults: defaults,
            appVersion: "1.5.0",
            build: "16"
        )

        client.track(event)
        try await waitForRequest(in: session)

        let request = try #require(await session.capturedRequests().first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Wianu/1.5.0 (macOS)")
        let body = try #require(request.httpBody)
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let payload = try #require(json["payload"] as? [String: Any])
        let data = try #require(payload["data"] as? [String: String])
        #expect(json["type"] as? String == "event")
        #expect(payload["website"] as? String == "website-id")
        #expect(payload["name"] as? String == event.rawValue)
        #expect(payload["url"] as? String == "/app")
        #expect(payload["hostname"] as? String == "wianu.com")
        #expect(Set(payload.keys) == ["id", "hostname", "url", "website", "name", "data"])
        let id = try #require(payload["id"] as? String)
        #expect(UUID(uuidString: id) != nil)
        #expect(defaults.string(forKey: AnalyticsPreference.distinctIDKey) == id)
        #expect(data == ["app_version": "1.5.0", "build": "16"])
        let bodyString = try #require(String(bytes: body, encoding: .utf8))
        #expect(!bodyString.contains("query"))
    }

    @Test func `distinct ID persists across clients and differs between installations`() async throws {
        let suiteName = "AnalyticsClientTests.identity.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let otherDefaults = try #require(UserDefaults(
            suiteName: "AnalyticsClientTests.other.\(UUID().uuidString)"
        ))
        var ids: [String] = []
        for store in try [defaults, #require(UserDefaults(suiteName: suiteName)), otherDefaults] {
            let session = AnalyticsFixtureSession()
            let client = AnalyticsClient(
                session: session,
                endpoint: URL(string: "https://analytics.example/api/send"),
                websiteID: "website-id",
                userDefaults: store,
                appVersion: "1",
                build: "1"
            )
            client.track(.appLaunched)
            try await waitForRequest(in: session)
            let request = try #require(await session.capturedRequests().first)
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let payload = try #require(json["payload"] as? [String: Any])
            try ids.append(#require(payload["id"] as? String))
        }
        #expect(ids[0] == ids[1])
        #expect(ids[0] != ids[2])
    }

    @Test func `opt out and missing configuration send nothing`() async throws {
        let defaults = try #require(UserDefaults(
            suiteName: "AnalyticsClientTests.disabled.\(UUID().uuidString)"
        ))
        let session = AnalyticsFixtureSession()
        let client = AnalyticsClient(
            session: session,
            endpoint: URL(string: "https://analytics.example/api/send"),
            websiteID: "website-id",
            userDefaults: defaults,
            appVersion: "1",
            build: "1"
        )

        #expect(client.isEnabled)
        defaults.set(false, forKey: AnalyticsPreference.enabledKey)
        client.track(.siteOpened)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await session.capturedRequests().isEmpty)
        #expect(defaults.object(forKey: AnalyticsPreference.distinctIDKey) == nil)

        defaults.set(true, forKey: AnalyticsPreference.enabledKey)
        let unconfigured = AnalyticsClient(
            session: session,
            endpoint: nil,
            websiteID: "",
            userDefaults: defaults,
            appVersion: "1",
            build: "1"
        )
        unconfigured.track(.siteOpened)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await session.capturedRequests().isEmpty)
        #expect(defaults.object(forKey: AnalyticsPreference.distinctIDKey) == nil)
    }

    private func waitForRequest(
        in session: AnalyticsFixtureSession
    ) async throws {
        for _ in 0 ..< 20 {
            if await !session.capturedRequests().isEmpty {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Expected an analytics request")
    }
}

@MainActor
private final class RecordingAnalyticsTracker: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

@MainActor
@Suite("Site opening analytics")
struct SiteOpeningAnalyticsTests {
    @Test func `explicit opens count once each while startup restoration does not`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        #expect(fixture.model.selection == .site(fixture.site.id))
        #expect(fixture.tracker.events == [.appLaunched])

        fixture.model.select(.site(fixture.site.id))
        #expect(fixture.tracker.events == [.appLaunched, .siteOpened])
        fixture.model.select(.site(fixture.site.id))
        #expect(fixture.tracker.events == [.appLaunched, .siteOpened, .siteOpened])
    }

    @Test func `search and provider actions each record one site open`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        fixture.model.search("Private Search", in: fixture.site)
        #expect(fixture.tracker.events == [.appLaunched, .siteOpened])
        #expect(fixture.model.destinationURL?.path == "/search")

        let media = TMDBMediaResult(
            id: 42,
            mediaType: .movie,
            title: "Private Title",
            overview: "",
            posterPath: nil,
            releaseDate: nil
        )
        fixture.model.openProvider(TMDBProvider(id: 1, name: "Private Provider", logoPath: nil), for: media)
        #expect(fixture.tracker.events == [.appLaunched, .siteOpened, .siteOpened])
    }

    @Test func `home missing sites and automatic URL matching do not record site opens`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        fixture.model.select(.home)
        fixture.model.select(nil)
        fixture.model.select(.site(UUID()))
        fixture.model.activateSite(matching: fixture.site.url)
        #expect(fixture.tracker.events == [.appLaunched])
    }
}

@MainActor
private struct AnalyticsAppFixture {
    let directory: URL
    let suiteName: String
    let defaults: UserDefaults
    let site: SavedSite
    let tracker: RecordingAnalyticsTracker
    let model: AppModel

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        suiteName = "SiteOpeningAnalyticsTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        site = SavedSite(
            name: "Private Service",
            urlString: "https://private.example",
            searchURLTemplate: "https://private.example/search?q={query}",
            tmdbProvider: TMDBProviderReference(id: 1, name: "Private Provider")
        )
        let sites = JSONFileStore<[SavedSite]>(fileName: "sites.json", folderName: "Tests", baseDirectory: directory)
        try sites.save([site])
        tracker = RecordingAnalyticsTracker()
        model = AppModel(
            siteStore: SiteStore(fileStore: sites),
            continueWatchingStore: ContinueWatchingStore(fileStore: JSONFileStore(
                fileName: "continue.json", folderName: "Tests", baseDirectory: directory
            )),
            watchlistStore: WatchlistStore(fileStore: JSONFileStore(
                fileName: "watchlist.json", folderName: "Tests", baseDirectory: directory
            )),
            userDefaults: defaults,
            tmdbClient: TMDBClient(session: LetterboxdTestSession(pages: [])),
            analytics: tracker
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}
