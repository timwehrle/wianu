import Foundation
import Testing
@testable import Wianu

@Suite("Analytics client")
struct AnalyticsClientTests {
    @Test(arguments: [
        AnalyticsEvent.searchOpened,
        .siteOpened,
        .homeOpened,
        .weeklyPickOpened,
        .continueWatchingOpened,
        .providerSelected,
        .onboardingStarted,
        .onboardingServicesOpened,
        .onboardingCompleted,
        .onboardingSkipped
    ])
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

        let properties = ["source": "getting-started", "onboarding_version": "1"]
        client.track(event, properties: properties)
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
        #expect(data == [
            "app_version": "1.5.0",
            "build": "16",
            "source": "getting-started",
            "onboarding_version": "1"
        ])

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

    @Test(arguments: [
        AnalyticsEvent.siteOpened,
        .homeOpened,
        .weeklyPickOpened,
        .continueWatchingOpened,
        .providerSelected,
        .onboardingStarted,
        .onboardingServicesOpened,
        .onboardingCompleted,
        .onboardingSkipped
    ])
    func `opt out and missing configuration send nothing`(event: AnalyticsEvent) async throws {
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
        client.track(event, properties: ["source": "first-launch"])
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
        unconfigured.track(event)
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
    private(set) var properties: [[String: String]] = []

    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        events.append(event)
        self.properties.append(properties)
    }
}

@MainActor
@Suite("Site opening analytics")
struct SiteOpeningAnalyticsTests {
    @Test(arguments: [false, true])
    func `failed site writes preserve saved state and can be retried`(isEditing: Bool) throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let model = fixture.model
        let originalSites = model.siteStore.sites
        let fileURL = fixture.directory.appending(path: "Tests/sites.json")
        let savedData = try Data(contentsOf: fileURL)

        try FileManager.default.removeItem(at: fileURL)
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: false)

        var draft = SiteDraft(site: fixture.site)
        draft.name = "Updated Service"
        let didSave = isEditing
            ? model.updateSite(fixture.site, with: draft)
            : model.addSite(draft)

        #expect(!didSave)
        #expect(model.siteStore.sites == originalSites)
        #expect(model.siteStore.persistenceError != nil)
        model.onboardingCompleted(source: .firstLaunch, servicesAddedCount: 1)
        #expect(fixture.tracker.events == [.appLaunched])

        try FileManager.default.removeItem(at: fileURL)
        try savedData.write(to: fileURL)

        let didRetry = isEditing
            ? model.updateSite(fixture.site, with: draft)
            : model.addSite(draft)

        #expect(didRetry)
        #expect(model.siteStore.persistenceError == nil)
        #expect(model.siteStore.sites.count == (isEditing ? 1 : 2))
        #expect(model.siteStore.sites.last?.name == "Updated Service")
        #expect(fixture.tracker.events == [.appLaunched, isEditing ? .siteEdited : .siteAdded])

        let restored = SiteStore(fileStore: JSONFileStore(
            fileName: "sites.json",
            folderName: "Tests",
            baseDirectory: fixture.directory
        ))
        #expect(restored.sites.map(\.id) == model.siteStore.sites.map(\.id))
        #expect(restored.sites.map(\.name) == model.siteStore.sites.map(\.name))
        #expect(restored.sites.map(\.tmdbProviders) == model.siteStore.sites.map(\.tmdbProviders))
    }

    @Test func `movie results save metadata immediately and avoid duplicate additions`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let media = watchlistMedia()
        #expect(fixture.model.addWatchlistItem(media))
        #expect(fixture.model.addWatchlistItem(media))
        #expect(fixture.model.watchlistStore.items.count == 1)
        #expect(fixture.tracker.events == [.appLaunched, .watchlistItemAdded])

        let reopened = WatchlistStore(fileStore: JSONFileStore(
            fileName: "watchlist.json",
            folderName: "Tests",
            baseDirectory: fixture.directory
        ))
        let item = try #require(reopened.items.first)
        #expect(item.title == media.title)
        #expect(item.year == 2024)
        #expect(item.url == media.letterboxdURL)
        #expect(item.tmdbID == media.id)
        #expect(item.tmdbMediaType == .movie)
        #expect(item.tmdbMetadata == media)
        #expect(reopened.contains(media))
    }

    @Test func `movie result matching respects media type and existing associations`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let store = fixture.model.watchlistStore
        let existing = store.add(title: "Existing", year: nil, url: nil)
        store.associate(id: existing.id, with: watchlistMedia(mediaType: .tv))
        #expect(!store.contains(watchlistMedia()))
        #expect(!fixture.model.addWatchlistItem(watchlistMedia(mediaType: .tv)))
        #expect(fixture.model.addWatchlistItem(watchlistMedia()))
        #expect(store.items.count == 2)
        #expect(fixture.tracker.events == [.appLaunched, .watchlistItemAdded])
    }

    @Test func `failed movie result saves can be retried without success analytics`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let destination = fixture.directory.appending(path: "Tests/watchlist.json")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)

        #expect(!fixture.model.addWatchlistItem(watchlistMedia()))
        #expect(fixture.model.watchlistStore.items.isEmpty)
        #expect(fixture.model.watchlistStore.persistenceError != nil)
        #expect(fixture.tracker.events == [.appLaunched])

        try FileManager.default.removeItem(at: destination)

        #expect(fixture.model.addWatchlistItem(watchlistMedia()))
        #expect(fixture.model.watchlistStore.items.count == 1)
        #expect(fixture.model.watchlistStore.persistenceError == nil)
        #expect(fixture.tracker.events == [.appLaunched, .watchlistItemAdded])
    }

    private func watchlistMedia(mediaType: TMDBMediaType = .movie) -> TMDBMediaResult {
        TMDBMediaResult(
            id: 42,
            mediaType: mediaType,
            title: "Selected Movie",
            overview: "A movie selected from search.",
            posterPath: "/poster.jpg",
            releaseDate: "2024-03-15"
        )
    }

    @Test func `onboarding records steps with completion properties`() throws {
        let fixture = try AnalyticsAppFixture(hasSites: false)
        defer { fixture.cleanup() }

        fixture.model.onboardingStarted(source: .firstLaunch)
        fixture.model.onboardingServicesOpened(source: .firstLaunch)
        fixture.model.onboardingCompleted(source: .firstLaunch, servicesAddedCount: 0)
        fixture.model.addSite(SiteDraft(name: "Private", address: "https://private.example"))
        fixture.model.onboardingCompleted(source: .firstLaunch, servicesAddedCount: 1)

        #expect(fixture.tracker.events == [
            .appLaunched,
            .onboardingStarted,
            .onboardingServicesOpened,
            .siteAdded,
            .onboardingCompleted
        ])
        #expect(fixture.tracker.properties[1] == [
            "source": "first-launch",
            "onboarding_version": "1"
        ])
        #expect(fixture.tracker.properties.last == [
            "source": "first-launch",
            "onboarding_version": "1",
            "services_added_count": "1"
        ])
    }

    @Test(arguments: [OnboardingStep.welcome, .services])
    func `manual onboarding records its source and explicit skip step`(step: OnboardingStep) throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        fixture.model.onboardingStarted(source: .gettingStarted)
        fixture.model.onboardingSkipped(source: .gettingStarted, step: step)

        #expect(fixture.tracker.events == [.appLaunched, .onboardingStarted, .onboardingSkipped])
        #expect(fixture.tracker.properties.last == [
            "source": "getting-started",
            "onboarding_version": "1",
            "step": step.rawValue
        ])
    }

    @Test(arguments: [false, true])
    func `startup selects Home without sites even with a stale saved selection`(hasSavedSelection: Bool) throws {
        let fixture = try AnalyticsAppFixture(hasSites: false, hasSavedSelection: hasSavedSelection)
        defer { fixture.cleanup() }

        #expect(fixture.model.selection == .home)
        #expect(fixture.model.navigationRequest == nil)
        #expect(fixture.tracker.events == [.appLaunched])
    }

    @Test func `additional selected provider routes through the saved site`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        var draft = SiteDraft(site: fixture.site)
        draft.tmdbProviders.append(TMDBProviderReference(id: 9999, name: "Another Provider"))
        fixture.model.updateSite(fixture.site, with: draft)
        let provider = TMDBProvider(id: 9999, name: "Another Provider", logoPath: nil)
        #expect(fixture.model.site(for: provider)?.id == fixture.site.id)
        #expect(fixture.model.site(for: TMDBProvider(id: 9998, name: "Unrelated", logoPath: nil)) == nil)
    }

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
        #expect(fixture.tracker.events == [.appLaunched, .siteOpened, .providerSelected, .siteOpened])
    }

    @Test func `home missing sites and automatic URL matching do not record site opens`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        fixture.model.select(.home)
        fixture.model.select(nil)
        fixture.model.select(.site(UUID()))
        fixture.model.activateSite(matching: fixture.site.url)
        #expect(fixture.tracker.events == [.appLaunched, .homeOpened])
    }

    @Test func `home selections count once per action`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        fixture.model.select(.home)
        fixture.model.select(.site(fixture.site.id))
        fixture.model.select(.home)
        #expect(fixture.tracker.events == [.appLaunched, .homeOpened, .siteOpened, .homeOpened])
    }

    @Test func `only valid saved Continue Watching pages record opens`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        let url = try #require(URL(string: "https://private.example/private-title"))
        let item = fixture.model.continueWatchingStore.save(siteID: fixture.site.id, title: "Private Title", url: url)
        fixture.model.select(.continueWatching(item.id))
        #expect(fixture.model.destinationURL == url)
        #expect(fixture.tracker.events == [.appLaunched, .continueWatchingOpened])
        fixture.model.select(.continueWatching(UUID()))
        #expect(fixture.tracker.events == [.appLaunched, .continueWatchingOpened])
    }

    @Test func `Automatic playback reuses saved Netflix entries without changing manual names`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }

        let originalURL = try #require(URL(string: "https://www.netflix.com/watch/123?trackId=456"))
        let item = fixture.model.continueWatchingStore.save(
            siteID: fixture.site.id, title: "My saved name", url: originalURL
        )
        let media = IdentificationFixtures.media()
        fixture.model.continueWatchingStore.associate(id: item.id, with: media)
        fixture.model.select(.continueWatching(item.id))

        let detectedURL = try #require(URL(string: "https://www.netflix.com/title/123"))
        fixture.model.saveAutomaticallyToContinueWatching(title: "Star Trek Beyond", url: detectedURL)

        let saved = try #require(fixture.model.continueWatchingStore.item(id: item.id))

        #expect(fixture.model.continueWatchingStore.items.count == 1)
        #expect(saved.title == "My saved name")
        #expect(saved.url == originalURL)
        #expect(saved.tmdbMetadata == media)
        #expect(!fixture.tracker.events.contains(.continueWatchingItemAdded))
    }

    @Test func `weekly picks record opening details without recording a site open`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        let media = TMDBMediaResult(
            id: 42,
            mediaType: .movie,
            title: "Private Title",
            overview: "",
            posterPath: nil,
            releaseDate: nil
        )
        fixture.model.openWeeklyPick(media)
        #expect(fixture.tracker.events == [.appLaunched, .weeklyPickOpened, .searchOpened])
        #expect(fixture.model.isCommandPalettePresented)
        #expect(fixture.model.tmdbSearch.selectedMedia == media)
    }

    @Test func `unavailable providers do not record selections or site opens`() throws {
        let fixture = try AnalyticsAppFixture()
        defer { fixture.cleanup() }
        let media = TMDBMediaResult(
            id: 42,
            mediaType: .movie,
            title: "Private Title",
            overview: "",
            posterPath: nil,
            releaseDate: nil
        )
        fixture.model.openProvider(TMDBProvider(id: 999, name: "Unconfigured Provider", logoPath: nil), for: media)
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

    init(hasSites: Bool = true, hasSavedSelection: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        suiteName = "SiteOpeningAnalyticsTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        site = SavedSite(
            name: "Private Service",
            urlString: "https://private.example",
            searchURLTemplate: "https://private.example/search?q={query}",
            tmdbProviders: [TMDBProviderReference(id: 1, name: "Private Provider")]
        )
        let sites = JSONFileStore<[SavedSite]>(fileName: "sites.json", folderName: "Tests", baseDirectory: directory)
        try sites.save(hasSites ? [site] : [])
        if hasSavedSelection {
            defaults.set(site.id.uuidString, forKey: "lastSelectedSiteID")
        }
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
