import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    struct NavigationRequest: Identifiable, Sendable {
        let id = UUID()
        let url: URL
    }

    let continueWatchingQueues: [ContinueWatchingController]
    let siteStore: SiteStore
    let watchlistStore: WatchlistStore
    let mediaIdentification: MediaIdentificationCoordinator
    private(set) var tmdbClient: TMDBClient
    private(set) var tmdbSearch: TMDBSearchModel
    private(set) var isCommandPalettePresented = false

    private(set) var selection: SidebarSelection?
    private(set) var navigationRequest: NavigationRequest?
    @ObservationIgnored
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private let analytics: any AnalyticsTracking

    private static let lastSelectedSiteKey = "lastSelectedSiteID"

    func continueWatchingSite(for service: ContinueWatchingService) -> SavedSite? {
        guard let adapter = continueWatchingQueues.first(where: { $0.id == service })?.adapter else { return nil }

        return siteStore.sites.first { adapter.matches($0.url) }
    }

    var sidebarContinueWatchingQueues: [ContinueWatchingController] {
        let registered = siteStore.sites.compactMap { site in
            continueWatchingQueues.first { $0.adapter.matches(site.url) }
        }
        let saved = continueWatchingQueues.filter { $0.updatedAt != nil }
        var seen: Set<ContinueWatchingService> = []

        return (registered + saved).filter { seen.insert($0.id).inserted }
    }

    func refreshContinueWatching(_ service: ContinueWatchingService) {
        guard let queue = continueWatchingQueues.first(where: { $0.id == service }),
              let site = continueWatchingSite(for: service), let siteURL = site.url,
              let url = queue.adapter.refreshURL(for: siteURL)
        else { return }

        queue.beginRefresh()
        select(.site(site.id))
        navigate(to: url)
    }

    var destinationURL: URL? {
        navigationRequest?.url
    }

    init() {
        continueWatchingQueues = ContinueWatchingAdapter.all.map {
            ContinueWatchingController(
                adapter: $0,
                fileStore: JSONFileStore(
                    fileName: "continue-watching-\($0.id.rawValue).json",
                    folderName: "Wianu"
                )
            )
        }
        siteStore = SiteStore()
        watchlistStore = WatchlistStore()
        userDefaults = .standard
        let analytics = AnalyticsClient(userDefaults: userDefaults)
        self.analytics = analytics
        let client = TMDBClient()
        mediaIdentification = MediaIdentificationCoordinator(
            watchlist: watchlistStore,
            client: client
        )
        tmdbClient = client
        tmdbSearch = TMDBSearchModel(
            client: client,
            userDefaults: userDefaults
        )
        restoreSelection()
        analytics.track(.appLaunched)
    }

    init(
        siteStore: SiteStore,
        watchlistStore: WatchlistStore,
        userDefaults: UserDefaults,
        tmdbClient: TMDBClient,
        analytics: (any AnalyticsTracking)? = nil
    ) {
        continueWatchingQueues = ContinueWatchingAdapter.all.map { ContinueWatchingController(adapter: $0) }
        self.siteStore = siteStore
        self.watchlistStore = watchlistStore
        self.userDefaults = userDefaults
        let analytics = analytics ?? DisabledAnalyticsTracker()
        self.analytics = analytics
        mediaIdentification = MediaIdentificationCoordinator(
            watchlist: watchlistStore,
            client: tmdbClient
        )
        self.tmdbClient = tmdbClient
        tmdbSearch = TMDBSearchModel(
            client: tmdbClient,
            userDefaults: userDefaults
        )
        restoreSelection()
        analytics.track(.appLaunched)
    }
}

extension AppModel {
    var selectedSite: SavedSite? {
        guard let selectedSiteID else { return nil }
        return siteStore.sites.first { $0.id == selectedSiteID }
    }

    var selectedContinueWatchingEntry: ContinueWatchingEntry? {
        guard case let .continueWatching(service, itemID) = selection else { return nil }

        return continueWatchingQueues.first { $0.id == service }?.entries.first { $0.id == itemID }
    }

    func destination(for selection: SidebarSelection?) -> URL? {
        switch selection {
        case let .site(siteID):
            siteStore.sites.first { $0.id == siteID }?.url
        case let .continueWatching(service, itemID):
            continueWatchingQueues.first { $0.id == service }?.entries.first { $0.id == itemID }?.url
        case let .watchlistItem(itemID):
            watchlistStore.item(id: itemID)?.url
        case .home, nil:
            nil
        }
    }

    func search(_ query: String, in site: SavedSite) {
        guard let searchURL = site.searchURL(for: query) else { return }

        dismissCommandPalette()
        select(.site(site.id))
        navigate(to: searchURL)
    }

    func showCommandPalette(query: String? = nil) {
        tmdbSearch.clearSelection()
        if let query {
            tmdbSearch.query = query
        } else {
            tmdbSearch.query = ""
        }
        tmdbSearch.queryChanged()
        isCommandPalettePresented = true
        tmdbSearch.requestFocus()
        analytics.track(.searchOpened)
    }

    func onboardingStarted(source: OnboardingSource) {
        trackOnboarding(.onboardingStarted, source: source)
    }

    func onboardingServicesOpened(source: OnboardingSource) {
        trackOnboarding(.onboardingServicesOpened, source: source)
    }

    func onboardingSkipped(source: OnboardingSource, step: OnboardingStep) {
        trackOnboarding(.onboardingSkipped, source: source, properties: ["step": step.rawValue])
    }

    func onboardingCompleted(source: OnboardingSource, servicesAddedCount: Int) {
        guard servicesAddedCount > 0, siteStore.persistenceError == nil else { return }

        trackOnboarding(
            .onboardingCompleted,
            source: source,
            properties: ["services_added_count": String(servicesAddedCount)]
        )
    }

    private func trackOnboarding(
        _ event: AnalyticsEvent,
        source: OnboardingSource,
        properties: [String: String] = [:]
    ) {
        analytics.track(event, properties: properties.merging([
            "source": source.rawValue,
            "onboarding_version": "1"
        ]) { _, value in value })
    }

    func settingsOpened() {
        analytics.track(.settingsOpened)
    }

    func updateCheckStarted() {
        analytics.track(.updateCheckStarted)
    }

    @discardableResult
    func addSite(_ draft: SiteDraft) -> Bool {
        guard siteStore.addSite(draft) else { return false }

        analytics.track(.siteAdded)
        return true
    }

    @discardableResult
    func updateSite(_ site: SavedSite, with draft: SiteDraft) -> Bool {
        guard siteStore.updateSite(id: site.id, with: draft) else { return false }

        analytics.track(.siteEdited)
        return true
    }

    func dismissCommandPalette() {
        isCommandPalettePresented = false
    }

    func openWeeklyPick(_ media: TMDBMediaResult) {
        analytics.track(.weeklyPickOpened)
        showCommandPalette(query: media.title)
        tmdbSearch.select(media)
    }

    func openProvider(_ provider: TMDBProvider, for media: TMDBMediaResult) {
        guard let site = siteStore.sites.first(where: {
            $0.tmdbProviders.contains(where: { $0.matches(provider) })
                && $0.isTMDBProviderActionable
        }), site.searchURL(for: media.title) != nil
        else { return }
        analytics.track(.providerSelected)
        search(media.title, in: site)
    }

    func site(for provider: TMDBProvider) -> SavedSite? {
        siteStore.sites.first {
            $0.tmdbProviders.contains(where: { $0.matches(provider) })
        }
    }

    func select(_ newSelection: SidebarSelection?) {
        isCommandPalettePresented = false
        selection = newSelection
        navigate(to: destination(for: newSelection))

        switch newSelection {
        case .home:
            analytics.track(.homeOpened)
        case .site where navigationRequest != nil:
            analytics.track(.siteOpened)
        case .continueWatching where navigationRequest != nil:
            analytics.track(.continueWatchingOpened)
        default:
            break
        }

        if let selectedSiteID {
            userDefaults.set(
                selectedSiteID.uuidString,
                forKey: Self.lastSelectedSiteKey
            )
        }
    }

    func deleteSite(_ site: SavedSite) {
        if selectedSiteID == site.id {
            selection = nil
            navigate(to: nil)
        }

        siteStore.deleteSite(id: site.id)
        analytics.track(.siteDeleted)

        if userDefaults.string(forKey: Self.lastSelectedSiteKey)
            == site.id.uuidString
        {
            userDefaults.removeObject(forKey: Self.lastSelectedSiteKey)
        }
    }

    func replaceImportedWatchlistItems(
        with items: [WatchlistItem]
    ) {
        let selectedItemID: WatchlistItem.ID? =
            if case let .watchlistItem(itemID) = selection {
                itemID
            } else {
                nil
            }

        watchlistStore.replaceImportedItems(with: items)

        if let selectedItemID,
           watchlistStore.item(id: selectedItemID) == nil
        {
            selection = nil
            navigate(to: nil)
        }
    }

    func letterboxdImportSucceeded() {
        analytics.track(.letterboxdImportSucceeded)
    }

    @discardableResult
    func addWatchlistItem(_ media: TMDBMediaResult) -> Bool {
        guard media.mediaType == .movie else { return false }
        guard !watchlistStore.contains(media) else { return true }
        guard watchlistStore.add(media) else { return false }

        analytics.track(.watchlistItemAdded)
        return true
    }

    func addWatchlistItem(title: String, year: Int?, url: URL?) {
        let item = watchlistStore.add(title: title, year: year, url: url)
        mediaIdentification.identifyInBackground(.watchlist(item.id))
        analytics.track(.watchlistItemAdded)
    }

    func updateWatchlistItem(
        _ item: WatchlistItem,
        title: String,
        year: Int?,
        url: URL?
    ) {
        watchlistStore.update(
            id: item.id,
            title: title,
            year: year,
            url: url
        )
        mediaIdentification.identifyInBackground(.watchlist(item.id))
    }

    func removeWatchlistItem(_ item: WatchlistItem) {
        if selection == .watchlistItem(item.id) {
            select(nil)
        }
        mediaIdentification.cancel(.watchlist(item.id))
        watchlistStore.remove(id: item.id)
        analytics.track(.watchlistItemRemoved)
    }

    func activateSite(matching url: URL?) {
        guard selection != .home,
              let url,
              let host = normalizedHost(for: url),
              let site = siteStore.sites.first(where: {
                  normalizedHost(for: $0.url) == host
              }),
              selection != .site(site.id)
        else { return }

        selection = .site(site.id)
        userDefaults.set(
            site.id.uuidString,
            forKey: Self.lastSelectedSiteKey
        )
    }

    func toggleWatchlist(title: String, url: URL) {
        if let item = watchlistStore.item(matching: url) {
            removeWatchlistItem(item)
            return
        }

        let trimmedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let savedTitle: String =
            if let site = selectedSite {
                PageTitleCleaner.clean(
                    trimmedTitle,
                    siteName: site.name
                )
            } else {
                trimmedTitle.isEmpty
                    ? url.host() ?? "Untitled Movie"
                    : trimmedTitle
            }

        let item = watchlistStore.add(
            title: savedTitle,
            year: nil,
            url: url
        )
        mediaIdentification.identifyInBackground(.watchlist(item.id))
        analytics.track(.watchlistItemAdded)
    }

    private var selectedSiteID: SavedSite.ID? {
        switch selection {
        case let .site(siteID):
            siteID
        case let .continueWatching(service, _):
            continueWatchingSite(for: service)?.id
        case .watchlistItem:
            nil
        case .home, nil:
            nil
        }
    }

    private func restoreSelection() {
        let savedID =
            userDefaults
                .string(forKey: Self.lastSelectedSiteKey)
                .flatMap(UUID.init(uuidString:))

        if let savedID, siteStore.sites.contains(where: { $0.id == savedID }) {
            selection = .site(savedID)
        } else if let firstSite = siteStore.sites.first {
            selection = .site(firstSite.id)
        } else {
            selection = .home
        }

        navigate(to: destination(for: selection))
    }

    private func navigate(to url: URL?) {
        navigationRequest = url.map(NavigationRequest.init(url:))
    }

    private func normalizedHost(for url: URL?) -> String? {
        guard var host = url?.host()?.lowercased() else { return nil }

        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }

        return host
    }
}
