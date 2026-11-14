import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Support prompt")
struct SupportPromptTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func withDefaults(_ test: (UserDefaults) -> Void) throws {
        let suite = "SupportPromptTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        test(defaults)
    }

    private func launch(_ defaults: UserDefaults, at date: Date) -> SupportPromptModel {
        let model = SupportPromptModel(defaults: defaults, now: date)
        model.recordSession()
        return model
    }

    @Test
    func `requires seven days and three separate sessions`() throws {
        try withDefaults { defaults in
            let window = UUID()
            let first = launch(defaults, at: start)
            first.recordSession()
            first.recordSession()
            first.presentIfNeeded(in: window, now: start + 7 * day)
            #expect(first.presentingWindowID == nil)

            let second = launch(defaults, at: start + day)
            second.presentIfNeeded(in: window, now: start + 7 * day)
            #expect(second.presentingWindowID == nil)

            let third = launch(defaults, at: start + 2 * day)
            third.presentIfNeeded(in: window, now: start + 7 * day - 1)
            #expect(third.presentingWindowID == nil)
            third.presentIfNeeded(in: window, now: start + 7 * day)
            #expect(third.presentingWindowID == window)
        }
    }

    @Test
    func `dismissal waits thirty days and only the presenting window can dismiss`() throws {
        try withDefaults { defaults in
            _ = launch(defaults, at: start)
            _ = launch(defaults, at: start + day)
            let model = launch(defaults, at: start + 7 * day)
            let window = UUID()
            model.presentIfNeeded(in: window, now: start + 7 * day)
            model.presentIfNeeded(in: UUID(), now: start + 7 * day)
            model.dismiss(in: UUID(), permanently: true, now: start + 7 * day)
            #expect(model.presentingWindowID == window)

            model.dismiss(in: window, now: start + 8 * day)
            // SwiftUI may also dismiss through the sheet binding after the button action.
            model.dismiss(in: window, now: start + 9 * day)
            let relaunched = launch(defaults, at: start + 37 * day)
            relaunched.presentIfNeeded(in: window, now: start + 38 * day - 1)
            #expect(relaunched.presentingWindowID == nil)
            relaunched.presentIfNeeded(in: window, now: start + 38 * day)
            #expect(relaunched.presentingWindowID == window)

            relaunched.dismiss(in: window, now: start + 38 * day)
            relaunched.presentIfNeeded(in: window, now: start + 68 * day - 1)
            #expect(relaunched.presentingWindowID == nil)
            relaunched.presentIfNeeded(in: window, now: start + 68 * day)
            #expect(relaunched.presentingWindowID == window)
        }
    }

    @Test
    func `permanent opt out survives relaunch`() throws {
        try withDefaults { defaults in
            _ = launch(defaults, at: start)
            _ = launch(defaults, at: start + day)
            let model = launch(defaults, at: start + 7 * day)
            let window = UUID()
            model.presentIfNeeded(in: window, now: start + 7 * day)
            model.dismiss(in: window, permanently: true, now: start + 7 * day)
            model.dismiss(in: window, now: start + 8 * day)

            let relaunched = launch(defaults, at: start + 365 * day)
            relaunched.presentIfNeeded(in: window, now: start + 365 * day)
            #expect(relaunched.presentingWindowID == nil)
        }
    }
}
