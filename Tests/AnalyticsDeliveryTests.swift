import Foundation
import Testing
@testable import Wianu

actor AnalyticsFixtureSession: AnalyticsSession {
    private(set) var requests: [URLRequest] = []
    private(set) var completedRequests = 0
    private(set) var maximumConcurrentRequests = 0
    private var activeRequests = 0
    private let statuses: [Int]
    private let delay: Duration

    init(statuses: [Int] = [], delay: Duration = .zero) {
        self.statuses = statuses
        self.delay = delay
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let index = requests.count
        requests.append(request)
        activeRequests += 1
        maximumConcurrentRequests = max(maximumConcurrentRequests, activeRequests)

        defer {
            activeRequests -= 1
            completedRequests += 1
        }

        try await Task.sleep(for: delay)

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: index < statuses.count ? statuses[index] : 204,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}

@MainActor
@Suite("Analytics delivery")
struct AnalyticsDeliveryTests {
    @Test func `events finish in order without concurrent requests`() async throws {
        let defaults = try freshDefaults()
        let session = AnalyticsFixtureSession(delay: .milliseconds(30))
        let client = makeClient(session: session, defaults: defaults)

        client.track(.onboardingStarted, properties: ["source": "getting-started"])
        client.track(.onboardingServicesOpened, properties: ["source": "getting-started"])
        client.track(.siteAdded)
        client.track(.onboardingCompleted, properties: ["source": "getting-started"])

        try await waitForCompletion(4, in: session)

        #expect(try await eventNames(in: session) == [
            "onboarding-started", "onboarding-services-opened", "site-added", "onboarding-completed"
        ])
        #expect(await session.maximumConcurrentRequests == 1)
    }

    @Test func `first launch start retries before subsequent steps and is acknowledged once`() async throws {
        let defaults = try freshDefaults()
        let session = AnalyticsFixtureSession(statuses: [503, 204, 204])
        let client = makeClient(session: session, defaults: defaults)
        let properties = ["source": "first-launch", "onboarding_version": "1"]

        client.track(.onboardingStarted, properties: properties)
        client.track(.onboardingStarted, properties: properties)
        client.track(.onboardingServicesOpened, properties: properties)

        try await waitForCompletion(3, in: session)

        #expect(try await eventNames(in: session) == [
            "onboarding-started", "onboarding-started", "onboarding-services-opened"
        ])
        #expect(defaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey))
        #expect(!defaults.bool(forKey: AnalyticsPreference.onboardingStartPendingKey))

        let reopenedSession = AnalyticsFixtureSession()
        let reopenedClient = makeClient(session: reopenedSession, defaults: defaults)
        reopenedClient.track(.onboardingStarted, properties: properties)
        reopenedClient.track(.appLaunched)

        try await waitForCompletion(1, in: reopenedSession)

        #expect(try await eventNames(in: reopenedSession) == ["app-launched"])
    }

    @Test func `permanent rejection does not retry or stall later events`() async throws {
        let defaults = try freshDefaults()
        let session = AnalyticsFixtureSession(statuses: [400, 204])
        let client = makeClient(session: session, defaults: defaults)

        client.track(.siteAdded)
        client.track(.siteOpened)

        try await waitForCompletion(2, in: session)

        #expect(try await eventNames(in: session) == ["site-added", "site-opened"])
    }

    @Test func `unacknowledged first launch start resumes on the next client`() async throws {
        let defaults = try freshDefaults()
        let failedSession = AnalyticsFixtureSession(statuses: [503, 503, 503])
        let client = makeClient(session: failedSession, defaults: defaults)

        client.track(.onboardingStarted, properties: ["source": "first-launch"])
        try await waitForCompletion(3, in: failedSession)

        #expect(!defaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey))
        #expect(defaults.bool(forKey: AnalyticsPreference.onboardingStartPendingKey))

        let recoveredSession = AnalyticsFixtureSession()
        let recoveredClient = makeClient(session: recoveredSession, defaults: defaults)
        try await waitForCompletion(1, in: recoveredSession)

        #expect(try await eventNames(in: recoveredSession) == ["onboarding-started"])
        #expect(defaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey))
        #expect(!defaults.bool(forKey: AnalyticsPreference.onboardingStartPendingKey))
        _ = recoveredClient
    }

    @Test func `opting out discards queued events and pending onboarding recovery`() async throws {
        let defaults = try freshDefaults()
        let session = AnalyticsFixtureSession(delay: .milliseconds(60))
        let client = makeClient(session: session, defaults: defaults)

        client.track(.appLaunched)
        try await waitForRequest(in: session)
        client.track(.onboardingStarted, properties: ["source": "first-launch"])
        defaults.set(false, forKey: AnalyticsPreference.enabledKey)

        try await waitForCompletion(1, in: session)
        try await Task.sleep(for: .milliseconds(20))

        #expect(try await eventNames(in: session) == ["app-launched"])
        #expect(!defaults.bool(forKey: AnalyticsPreference.onboardingStartPendingKey))

        let reopenedSession = AnalyticsFixtureSession()
        let reopenedClient = makeClient(session: reopenedSession, defaults: defaults)
        #expect(await reopenedSession.capturedRequests().isEmpty)
        #expect(!reopenedClient.isEnabled)
    }

    private func freshDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "AnalyticsClientTests.delivery.\(UUID().uuidString)"))
    }

    @MainActor
    private func makeClient(session: AnalyticsFixtureSession, defaults: UserDefaults) -> AnalyticsClient {
        AnalyticsClient(
            session: session,
            endpoint: URL(string: "https://analytics.example/api/send"),
            websiteID: "website-id",
            userDefaults: defaults,
            appVersion: "1",
            build: "1"
        )
    }

    private func eventNames(in session: AnalyticsFixtureSession) async throws -> [String] {
        try await session.capturedRequests().map { request in
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let payload = try #require(json["payload"] as? [String: Any])
            return try #require(payload["name"] as? String)
        }
    }

    private func waitForCompletion(_ count: Int, in session: AnalyticsFixtureSession) async throws {
        for _ in 0 ..< 200 {
            if await session.completedRequests >= count {
                return
            }

            try await Task.sleep(for: .milliseconds(10))
        }

        Issue.record("Expected \(count) completed analytics requests")
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
