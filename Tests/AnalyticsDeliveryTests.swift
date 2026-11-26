import Foundation
import Testing
@testable import Wianu

actor AnalyticsFixtureSession: AnalyticsSession {
    private let requestEvents = AsyncStream<Int>.makeStream()
    private let completionEvents = AsyncStream<Int>.makeStream()
    private(set) var requests: [URLRequest] = []
    private(set) var completedRequests = 0
    private(set) var maximumConcurrentRequests = 0
    private var activeRequests = 0
    private let statuses: [Int]
    private let delay: Duration
    private let responseData: Data
    private let responseHeaders: [String: String]

    init(
        statuses: [Int] = [], delay: Duration = .zero,
        responseData: Data = Data(
            """
            {
              "cache": "session-cache",
              "sessionId": "00000000-0000-0000-0000-000000000001",
              "visitId": "00000000-0000-0000-0000-000000000002"
            }
            """
            .utf8
        ),
        responseHeaders: [String: String] = [:]
    ) {
        self.responseHeaders = responseHeaders
        self.responseData = responseData
        self.statuses = statuses
        self.delay = delay
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let index = requests.count
        requests.append(request)
        requestEvents.continuation.yield(requests.count)
        activeRequests += 1
        maximumConcurrentRequests = max(maximumConcurrentRequests, activeRequests)

        defer {
            activeRequests -= 1
            completedRequests += 1
            completionEvents.continuation.yield(completedRequests)
        }

        try await Task.sleep(for: delay)

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: index < statuses.count ? statuses[index] : 200,
            httpVersion: nil,
            headerFields: responseHeaders
        )!
        return (responseData, response)
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }

    func completionStream() -> AsyncStream<Int> {
        completionEvents.stream
    }

    func requestStream() -> AsyncStream<Int> {
        requestEvents.stream
    }
}

func waitForTestEvent<T: Sendable>(
    in stream: AsyncStream<T>, timeout: Duration, matching predicate: @escaping @Sendable (T) -> Bool
) async throws -> Bool {
    try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask {
            for await value in stream where predicate(value) {
                return true
            }
            return false
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            return false
        }
        defer { group.cancelAll() }
        return try await group.next() ?? false
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
        let session = AnalyticsFixtureSession(statuses: [503, 200, 200])
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
        let session = AnalyticsFixtureSession(statuses: [400, 200])
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

    @Test func `session cache is reused only in memory`() async throws {
        let defaults = try freshDefaults()
        let response = Data(
            """
            {
              "cache": "session-cache",
              "sessionId": "00000000-0000-0000-0000-000000000001",
              "visitId": "00000000-0000-0000-0000-000000000002"
            }
            """
            .utf8
        )
        let session = AnalyticsFixtureSession(responseData: response)
        let client = makeClient(session: session, defaults: defaults)
        client.track(.appLaunched)
        client.track(.siteAdded)
        try await waitForCompletion(2, in: session)

        let requests = await session.capturedRequests()
        #expect(requests[0].value(forHTTPHeaderField: "x-umami-cache") == nil)
        #expect(requests[1].value(forHTTPHeaderField: "x-umami-cache") == "session-cache")
        let reopenedSession = AnalyticsFixtureSession()
        let reopened = makeClient(session: reopenedSession, defaults: defaults)
        reopened.track(.appLaunched)
        try await waitForCompletion(1, in: reopenedSession)
        #expect(await reopenedSession.capturedRequests()[0].value(forHTTPHeaderField: "x-umami-cache") == nil)
    }

    @Test func `opt out cancels in flight delivery and queued events cannot return after reenable`() async throws {
        let defaults = try freshDefaults()
        let session = AnalyticsFixtureSession(delay: .seconds(1))
        let client = makeClient(session: session, defaults: defaults)
        client.track(.appLaunched)
        try await waitForRequest(in: session)
        client.track(.siteAdded)
        client.track(.onboardingStarted, properties: ["source": "first-launch"])

        client.setEnabled(false)
        client.setEnabled(true)
        client.track(.searchOpened)
        try await waitForCompletion(2, in: session)

        #expect(try await eventNames(in: session) == ["app-launched", "search-opened"])
        #expect(!defaults.bool(forKey: AnalyticsPreference.onboardingStartPendingKey))
        #expect(!defaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey))
    }

    @Test(arguments: [
        #"{"beep":"boop"}"#,
        #"{"disabled":true}"#,
        "",
        #"{"cache":"","sessionId":"invalid","visitId":"invalid"}"#
    ])
    func `ignored or invalid success responses do not acknowledge onboarding`(body: String) async throws {
        let defaults = try freshDefaults()
        let session = AnalyticsFixtureSession(responseData: Data(body.utf8))
        let client = makeClient(session: session, defaults: defaults)
        client.track(.onboardingStarted, properties: ["source": "first-launch"])
        try await waitForCompletion(1, in: session)

        #expect(!defaults.bool(forKey: AnalyticsPreference.onboardingStartDeliveredKey))
        #expect(defaults.bool(forKey: AnalyticsPreference.onboardingStartPendingKey))
        #expect(await session.capturedRequests().count == 1)
    }

    @Test func `pending queue is bounded`() async throws {
        let session = AnalyticsFixtureSession()
        let client = try makeClient(session: session, defaults: freshDefaults())

        for _ in 0 ..< 150 {
            client.track(.siteOpened)
        }
        try await waitForCompletion(100, in: session)

        #expect(await session.capturedRequests().count == 100)
        #expect(await session.maximumConcurrentRequests == 1)
    }

    @Test(arguments: [false, true])
    func `rate limited delivery respects Retry After`(useDateHeader: Bool) async throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let value = useDateHeader ? formatter.string(from: .now.addingTimeInterval(2)) : "1"
        let earliestRetry = useDateHeader
            ? try #require(formatter.date(from: value)) : Date.now.addingTimeInterval(1)
        let session = AnalyticsFixtureSession(statuses: [429, 200], responseHeaders: ["Retry-After": value])
        let client = try makeClient(session: session, defaults: freshDefaults())
        client.track(.siteOpened)
        try await waitForCompletion(2, in: session)

        #expect(Date.now >= earliestRetry)
        #expect(try await eventNames(in: session) == ["site-opened", "site-opened"])
    }

    @Test func `server backoff also applies to the next queued event after retry exhaustion`() async throws {
        let session = AnalyticsFixtureSession(
            statuses: [429, 429, 429, 200], responseHeaders: ["Retry-After": "1"]
        )
        let client = try makeClient(session: session, defaults: freshDefaults())
        let started = ContinuousClock.now
        client.track(.siteOpened)
        client.track(.appLaunched)
        try await waitForCompletion(4, in: session)

        #expect(ContinuousClock.now - started >= .seconds(3))
        #expect(try await eventNames(in: session) == ["site-opened", "site-opened", "site-opened", "app-launched"])
    }

    @Test func `opting out cancels server requested backoff`() async throws {
        let session = AnalyticsFixtureSession(statuses: [429], responseHeaders: ["Retry-After": "3600"])
        let client = try makeClient(session: session, defaults: freshDefaults())
        client.track(.siteOpened)
        try await waitForCompletion(1, in: session)

        client.setEnabled(false)
        client.setEnabled(true)
        client.track(.searchOpened)
        try await waitForCompletion(2, in: session)

        #expect(try await eventNames(in: session) == ["site-opened", "search-opened"])
    }

    @Test(arguments: [
        ("https://www.paramountplus.com", "paramountPlus"),
        ("https://www.peacocktv.com", "peacock"),
        ("https://www.crunchyroll.com", "crunchyroll"),
        ("https://www.amazon.co.jp/gp/video", "primeVideo"),
        ("https://www.max.com", "hboMax"),
        ("https://tv.youtube.com", "youtubeTV"),
        ("https://www.youtube.com", "youtube"),
        ("https://plus.rtl.de", "rtlPlus"),
        ("https://www.jiohotstar.com", "jioHotstar"),
        ("https://www.hotstar.com", "jioHotstar"),
        ("https://www.iq.com", "iqiyi"),
        ("https://wetv.vip", "tencentVideo"),
        ("https://v.qq.com", "tencentVideo"),
        ("https://www.youku.tv", "youku"),
        ("https://www.zee5.com", "zee5"),
        ("https://globoplay.globo.com", "globoplay"),
        ("https://shahid.mbc.net", "shahid"),
        ("https://www.osnplus.com", "osnPlus"),
        ("https://www.stan.com.au", "stan"),
        ("https://www.crave.ca", "crave"),
        ("https://NETFLIX.COM/browse?private=title", "netflix"),
        ("https://notnetflix.com", "other"),
        ("https://netflix.com.private.example", "other"),
        ("https://private.example/netflix.com", "other"),
        ("https://www.apple.com", "other")
    ])
    func `services use fixed labels and match domain boundaries`(address: String, expected: String) {
        #expect(AnalyticsService.name(for: URL(string: address)) == expected)
        #expect(AnalyticsService.isKnown(expected))
        #expect(!AnalyticsService.isKnown(address))
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
        if await session.completedRequests >= count {
            return
        }

        let completions = await session.completionStream()
        let completed = try await waitForTestEvent(in: completions, timeout: .seconds(20)) { $0 >= count }
        try #require(completed, "Expected \(count) completed analytics requests")
    }

    private func waitForRequest(
        in session: AnalyticsFixtureSession
    ) async throws {
        let requests = await session.requestStream()
        let started = try await waitForTestEvent(in: requests, timeout: .seconds(20)) { $0 >= 1 }
        try #require(started, "Expected an analytics request")
    }
}
