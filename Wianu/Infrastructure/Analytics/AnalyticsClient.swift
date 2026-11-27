import Foundation
import OSLog

enum AnalyticsEvent: String, Sendable {
    case onboardingStarted = "onboarding-started"
    case onboardingServicesOpened = "onboarding-services-opened"
    case onboardingCompleted = "onboarding-completed"
    case onboardingSkipped = "onboarding-skipped"
    case appLaunched = "app-launched"
    case searchOpened = "search-opened"
    case homeOpened = "home-opened"
    case weeklyPickOpened = "weekly-pick-opened"
    case continueWatchingOpened = "continue-watching-opened"
    case providerSelected = "provider-selected"
    case providerSelectionFailed = "provider-selection-failed"
    case letterboxdImportSucceeded = "letterboxd-import-succeeded"
    case watchlistItemAdded = "watchlist-item-added"
    case watchlistItemRemoved = "watchlist-item-removed"
    case siteAdded = "site-added"
    case siteOpened = "site-opened"
    case siteEdited = "site-edited"
    case siteDeleted = "site-deleted"
    case settingsOpened = "settings-opened"
    case updateCheckStarted = "update-check-started"
    case supportPromptShown = "support-prompt-shown"
    case supportPromptClicked = "support-prompt-clicked"
    case supportPromptDismissed = "support-prompt-dismissed"
    case supportPromptDontAskAgain = "support-prompt-dont-ask-again"
}

enum AnalyticsPage: String, Sendable {
    case home, search, watchlist, settings
    case continueWatching = "continue-watching"
    case service

    var path: String {
        "/app/" + rawValue
    }
}

enum AnalyticsService {
    private static let services: [(name: String, domains: [String])] = [
        ("netflix", ["netflix.com"]),
        ("primeVideo", [
            "primevideo.com", "amazon.com", "amazon.de", "amazon.co.uk", "amazon.co.jp",
            "amazon.in", "amazon.com.au", "amazon.fr", "amazon.it", "amazon.es", "amazon.ca",
            "amazon.com.br", "amazon.com.mx", "amazon.nl", "amazon.pl", "amazon.se"
        ]),
        ("disneyPlus", ["disneyplus.com"]),
        ("appleTV", ["tv.apple.com"]),
        ("hboMax", ["hbomax.com", "max.com"]),
        ("youtubeTV", ["tv.youtube.com"]),
        ("youtube", ["youtube.com", "youtu.be"]),
        ("hulu", ["hulu.com"]),
        ("paramountPlus", ["paramountplus.com"]),
        ("peacock", ["peacocktv.com"]),
        ("crunchyroll", ["crunchyroll.com"]),
        ("tubi", ["tubitv.com", "tubi.tv"]),
        ("plutoTV", ["pluto.tv"]),
        ("mubi", ["mubi.com"]),
        ("rakutenTV", ["rakuten.tv"]),
        ("discoveryPlus", ["discoveryplus.com"]),
        ("dazn", ["dazn.com"]),
        ("nowTV", ["nowtv.com"]),
        ("skyShowtime", ["skyshowtime.com"]),
        ("canalPlus", ["canalplus.com"]),
        ("rtlPlus", ["plus.rtl.de", "rtlplus.de", "rtlplus.com"]),
        ("wow", ["wowtv.de"]),
        ("joyn", ["joyn.de", "joyn.at", "joyn.ch"]),
        ("arte", ["arte.tv"]),
        ("jioHotstar", ["jiohotstar.com", "hotstar.com"]),
        ("zee5", ["zee5.com"]),
        ("sonyLIV", ["sonyliv.com"]),
        ("iqiyi", ["iq.com", "iqiyi.com"]),
        ("tencentVideo", ["v.qq.com", "wetv.vip"]),
        ("youku", ["youku.com", "youku.tv"]),
        ("viu", ["viu.com"]),
        ("viki", ["viki.com"]),
        ("uNext", ["unext.jp"]),
        ("abema", ["abema.tv"]),
        ("globoplay", ["globoplay.globo.com"]),
        ("stan", ["stan.com.au"]),
        ("binge", ["binge.com.au"]),
        ("crave", ["crave.ca"]),
        ("shahid", ["shahid.mbc.net"]),
        ("osnPlus", ["osnplus.com"])
    ]

    static func name(for url: URL?) -> String {
        guard let host = url?.host()?.lowercased() else { return "other" }

        return services.first { service in
            service.domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }?.name ?? "other"
    }

    static func isKnown(_ name: String) -> Bool {
        name == "other" || services.contains { $0.name == name }
    }
}

enum AnalyticsPreference {
    static let enabledKey = "anonymousUsageAnalyticsEnabled"
    static let distinctIDKey = "anonymousUsageAnalyticsDistinctID"
    static let onboardingStartPendingKey = "onboardingStartPending"
    static let onboardingStartDeliveredKey = "onboardingStartDelivered"
}

@MainActor
protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String])
    func pageview(_ page: AnalyticsPage)
    func setEnabled(_ enabled: Bool)
}

extension AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        track(event, properties: [:])
    }
}

enum OnboardingSource: String {
    case firstLaunch = "first-launch"
    case gettingStarted = "getting-started"
}

enum OnboardingStep: String {
    case welcome
    case services
}

nonisolated protocol AnalyticsSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AnalyticsSession {}

@MainActor
final class AnalyticsClient: AnalyticsTracking {
    private let session: any AnalyticsSession
    private let endpoint: URL?
    private let websiteID: String
    private let userDefaults: UserDefaults
    private let appVersion: String
    private let build: String
    private var deliveryTask: Task<Void, Never>?
    private var pending: [(request: URLRequest, event: AnalyticsEvent?, isFirstLaunchOnboarding: Bool)] = []
    private var currentPage: AnalyticsPage?
    private var cache: String?
    private var retryNotBefore: Date?
    private var generation = 0
    private let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString

    private static let maximumPendingEvents = 100

    private static let onboardingProperties = [
        "source": OnboardingSource.firstLaunch.rawValue,
        "onboarding_version": "1"
    ]

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Wianu",
        category: "Analytics"
    )

    var isEnabled: Bool {
        if userDefaults.object(forKey: AnalyticsPreference.enabledKey) == nil {
            return true
        }
        return userDefaults.bool(forKey: AnalyticsPreference.enabledKey)
    }

    convenience init(
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard
    ) {
        let baseURL = (bundle.object(
            forInfoDictionaryKey: "UmamiBaseURL"
        ) as? String).flatMap(Self.validConfigurationValue)
            .flatMap(URL.init(string:))

        let websiteID = (bundle.object(
            forInfoDictionaryKey: "UmamiWebsiteID"
        ) as? String).flatMap(Self.validConfigurationValue) ?? ""

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10

        self.init(
            session: URLSession(configuration: configuration),
            endpoint: baseURL?.appending(path: "api/send"),
            websiteID: websiteID,
            userDefaults: userDefaults,
            appVersion: bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            build: bundle.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown"
        )
    }

    init(
        session: any AnalyticsSession,
        endpoint: URL?,
        websiteID: String,
        userDefaults: UserDefaults,
        appVersion: String,
        build: String
    ) {
        self.session = session
        self.endpoint = endpoint
        self.websiteID = websiteID
        self.userDefaults = userDefaults
        self.appVersion = appVersion
        self.build = build

        if !isEnabled {
            userDefaults.removeObject(forKey: AnalyticsPreference.onboardingStartPendingKey)
        } else if userDefaults.bool(forKey: AnalyticsPreference.onboardingStartPendingKey) {
            track(.onboardingStarted, properties: Self.onboardingProperties)
        }
    }

    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        guard isEnabled else {
            userDefaults.removeObject(forKey: AnalyticsPreference.onboardingStartPendingKey)
            return
        }

        var properties = properties
        switch event {
        case .letterboxdImportSucceeded, .onboardingCompleted, .providerSelected, .siteAdded, .siteEdited:
            properties["status"] = "success"
        case .providerSelectionFailed:
            properties["status"] = "failure"
        default:
            break
        }

        guard let request = makeRequest(event, properties: properties) else { return }

        let isFirstLaunchOnboarding = properties["source"] == OnboardingSource.firstLaunch.rawValue
            && [.onboardingStarted, .onboardingServicesOpened, .onboardingCompleted, .onboardingSkipped].contains(event)

        if isFirstLaunchOnboarding, !userDefaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey) {
            userDefaults.set(true, forKey: AnalyticsPreference.onboardingStartPendingKey)
        }

        enqueue(request, event: event, isFirstLaunchOnboarding: isFirstLaunchOnboarding)
    }

    func pageview(_ page: AnalyticsPage) {
        guard isEnabled, pending.count < Self.maximumPendingEvents, currentPage != page,
              let request = makeRequest(nil, properties: [:], page: page)
        else { return }

        currentPage = page
        enqueue(request, event: nil, isFirstLaunchOnboarding: false)
    }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: AnalyticsPreference.enabledKey)

        guard !enabled else { return }

        generation += 1
        deliveryTask?.cancel()
        deliveryTask = nil
        pending.removeAll()
        currentPage = nil
        cache = nil
        retryNotBefore = nil
        userDefaults.removeObject(forKey: AnalyticsPreference.onboardingStartPendingKey)
    }

    private func enqueue(_ request: URLRequest, event: AnalyticsEvent?, isFirstLaunchOnboarding: Bool) {
        // Bound memory when offline. Delivery stays serial to preserve funnel ordering.
        guard pending.count < Self.maximumPendingEvents else { return }

        pending.append((request, event, isFirstLaunchOnboarding))
        guard deliveryTask == nil else { return }

        let deliveryGeneration = generation
        deliveryTask = Task { [weak self] in
            guard let self else { return }

            while !pending.isEmpty, isEnabled, !Task.isCancelled {
                let (request, event, isFirstLaunchOnboarding) = pending.removeFirst()

                if isFirstLaunchOnboarding {
                    guard await deliverOnboardingStart() else { continue }
                    if event == .onboardingStarted {
                        continue
                    }
                }

                _ = await send(request)
            }

            guard generation == deliveryGeneration else { return }

            pending.removeAll()
            if !isEnabled {
                userDefaults.removeObject(forKey: AnalyticsPreference.onboardingStartPendingKey)
            }
            deliveryTask = nil
        }
    }

    private func deliverOnboardingStart() async -> Bool {
        if userDefaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey) {
            return true
        }

        guard let request = makeRequest(.onboardingStarted, properties: Self.onboardingProperties),
              await send(request),
              isEnabled, !Task.isCancelled else { return false }

        userDefaults.set(true, forKey: AnalyticsPreference.onboardingStartDeliveredKey)
        userDefaults.removeObject(forKey: AnalyticsPreference.onboardingStartPendingKey)
        return true
    }

    private func makeRequest(
        _ event: AnalyticsEvent?, properties: [String: String], page: AnalyticsPage? = nil
    ) -> URLRequest? {
        guard let endpoint, !websiteID.isEmpty else { return nil }

        let payload = RequestBody(
            payload: Payload(
                id: distinctID,
                hostname: "wianu.com",
                url: (page ?? currentPage)?.path ?? "/app",
                website: websiteID,
                name: event?.rawValue,
                data: event == nil ? nil : safeProperties(properties).merging([
                    "app_version": appVersion,
                    "build": build,
                    "macos_version": macOSVersion
                ]) { _, value in value }
            )
        )

        guard let data = try? JSONEncoder().encode(payload) else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Wianu/\(appVersion) (macOS)",
            forHTTPHeaderField: "User-Agent"
        )

        return request
    }

    private func safeProperties(_ properties: [String: String]) -> [String: String] {
        // Only bounded, structured metadata may cross this boundary.
        properties.filter { key, value in
            switch key {
            case "source": ["first-launch", "getting-started"].contains(value)
            case "onboarding_version": value == "1"
            case "step": ["welcome", "services"].contains(value)
            case "status": ["success", "failure"].contains(value)
            case "provider_id", "services_added_count": Int(value).map { $0 >= 0 } ?? false
            case "provider": ContinueWatchingService.allCases.contains { $0.rawValue == value }
            case "service": AnalyticsService.isKnown(value)
            default: false
            }
        }
    }

    private func send(_ request: URLRequest) async -> Bool {
        for attempt in 0 ..< 3 {
            guard isEnabled, !Task.isCancelled else { return false }

            do {
                if let retryNotBefore, retryNotBefore > .now {
                    try await Task.sleep(for: .seconds(retryNotBefore.timeIntervalSinceNow))
                }

                try Task.checkCancellation()
                guard isEnabled else { return false }

                var request = request
                request.setValue(cache, forHTTPHeaderField: "x-umami-cache")
                let (data, response) = try await session.data(for: request)

                guard isEnabled, !Task.isCancelled, let http = response as? HTTPURLResponse else { return false }

                if (200 ..< 300).contains(http.statusCode) {
                    // Umami can return HTTP 200 for ignored bot requests as well.
                    guard let response = try? JSONDecoder().decode(DeliveryResponse.self, from: data),
                          !response.cache.isEmpty else { return false }

                    cache = response.cache
                    return true
                }

                guard http.statusCode == 429 || (500 ..< 600).contains(http.statusCode) else {
                    Self.logger.debug("Analytics request was not accepted")
                    return false
                }

                retryNotBefore = Self.retryDate(for: http)
            } catch is CancellationError {
                return false
            } catch {
                Self.logger.debug(
                    "Analytics request failed: \(String(describing: error), privacy: .private)"
                )
            }

            if attempt < 2 {
                do {
                    try await Task.sleep(for: .milliseconds(250 * (attempt + 1)))
                } catch {
                    return false
                }
            }
        }

        return false
    }

    private static func retryDate(for response: HTTPURLResponse) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }

        if let seconds = Int(value), seconds >= 0 {
            return Date.now.addingTimeInterval(TimeInterval(seconds))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }

    private var distinctID: String {
        if let existing = userDefaults.string(forKey: AnalyticsPreference.distinctIDKey),
           UUID(uuidString: existing) != nil
        {
            return existing
        }
        let id = UUID().uuidString
        userDefaults.set(id, forKey: AnalyticsPreference.distinctIDKey)
        return id
    }

    private static func validConfigurationValue(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    private struct DeliveryResponse: Decodable {
        let cache: String
        let sessionId: UUID
        let visitId: UUID
    }

    private struct RequestBody: Encodable {
        let type = "event"
        let payload: Payload
    }

    private struct Payload: Encodable {
        let id: String
        let hostname: String
        let url: String
        let website: String
        let name: String?
        let data: [String: String]?
    }
}

@MainActor
struct DisabledAnalyticsTracker: AnalyticsTracking {
    func pageview(_ page: AnalyticsPage) {}
    func setEnabled(_ enabled: Bool) {}
    func track(_ event: AnalyticsEvent, properties: [String: String]) {}
}
