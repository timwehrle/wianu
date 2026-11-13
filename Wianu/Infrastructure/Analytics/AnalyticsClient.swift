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
    case letterboxdImportSucceeded = "letterboxd-import-succeeded"
    case watchlistItemAdded = "watchlist-item-added"
    case watchlistItemRemoved = "watchlist-item-removed"
    case siteAdded = "site-added"
    case siteOpened = "site-opened"
    case siteEdited = "site-edited"
    case siteDeleted = "site-deleted"
    case settingsOpened = "settings-opened"
    case updateCheckStarted = "update-check-started"
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

        guard let request = makeRequest(event, properties: properties) else { return }

        let isFirstLaunchOnboarding = properties["source"] == OnboardingSource.firstLaunch.rawValue
            && [.onboardingStarted, .onboardingServicesOpened, .onboardingCompleted, .onboardingSkipped].contains(event)

        if isFirstLaunchOnboarding, !userDefaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey) {
            userDefaults.set(true, forKey: AnalyticsPreference.onboardingStartPendingKey)
        }

        let previousTask = deliveryTask

        deliveryTask = Task {
            await previousTask?.value

            guard isEnabled else {
                userDefaults.removeObject(forKey: AnalyticsPreference.onboardingStartPendingKey)
                return
            }

            if isFirstLaunchOnboarding {
                guard await deliverOnboardingStart(), event != .onboardingStarted else { return }
            }

            _ = await send(request)
        }
    }

    private func deliverOnboardingStart() async -> Bool {
        if userDefaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey) {
            return true
        }

        guard let request = makeRequest(.onboardingStarted, properties: Self.onboardingProperties),
              await send(request)
        else { return false }

        userDefaults.set(true, forKey: AnalyticsPreference.onboardingStartDeliveredKey)
        userDefaults.removeObject(forKey: AnalyticsPreference.onboardingStartPendingKey)
        return true
    }

    private func makeRequest(_ event: AnalyticsEvent, properties: [String: String]) -> URLRequest? {
        guard let endpoint, !websiteID.isEmpty else { return nil }

        let payload = RequestBody(
            payload: Payload(
                id: distinctID,
                hostname: "wianu.com",
                url: "/app",
                website: websiteID,
                name: event.rawValue,
                data: properties.merging([
                    "app_version": appVersion,
                    "build": build
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

    private func send(_ request: URLRequest) async -> Bool {
        for attempt in 0 ..< 3 {
            guard isEnabled, !Task.isCancelled else { return false }

            do {
                let (_, response) = try await session.data(for: request)

                guard let http = response as? HTTPURLResponse else { return false }

                if (200 ..< 300).contains(http.statusCode) {
                    return true
                }

                guard http.statusCode == 429 || (500 ..< 600).contains(http.statusCode) else {
                    Self.logger.debug("Analytics request was not accepted")
                    return false
                }
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

    private struct RequestBody: Encodable {
        let type = "event"
        let payload: Payload
    }

    private struct Payload: Encodable {
        let id: String
        let hostname: String
        let url: String
        let website: String
        let name: String
        let data: [String: String]
    }
}

@MainActor
struct DisabledAnalyticsTracker: AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String]) {}
}
