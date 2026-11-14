import Foundation
import Observation

@MainActor
@Observable
final class SupportPromptModel {
    /// This fixed app-owned URL is valid by construction.
    static let supportURL = URL(string: "https://ko-fi.com/timwehrle")!

    private(set) var presentingWindowID: UUID?
    private let defaults: UserDefaults
    private var hasRecordedSession = false

    private enum Key {
        static let firstLaunch = "supportFirstLaunch"
        static let sessionCount = "supportSessionCount"
        static let nextPrompt = "supportNextPrompt"
        static let disabled = "supportPromptsDisabled"
    }

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults

        if defaults.object(forKey: Key.firstLaunch) == nil {
            defaults.set(now, forKey: Key.firstLaunch)
        }
    }

    /// Count once per app process, rather than once per window or foreground transition.
    func recordSession() {
        guard !hasRecordedSession else { return }

        hasRecordedSession = true
        defaults.set(defaults.integer(forKey: Key.sessionCount) + 1, forKey: Key.sessionCount)
    }

    func presentIfNeeded(in windowID: UUID, now: Date = .now) {
        guard presentingWindowID == nil,
              !defaults.bool(forKey: Key.disabled),
              defaults.integer(forKey: Key.sessionCount) >= 3,
              let firstLaunch = defaults.object(forKey: Key.firstLaunch) as? Date
        else { return }

        let nextPrompt = defaults.object(forKey: Key.nextPrompt) as? Date
            ?? firstLaunch.addingTimeInterval(7 * 24 * 60 * 60)
        guard now >= nextPrompt else { return }

        presentingWindowID = windowID
    }

    func dismiss(in windowID: UUID, permanently: Bool = false, now: Date = .now) {
        guard presentingWindowID == windowID else { return }

        if permanently {
            defaults.set(true, forKey: Key.disabled)
        } else {
            defaults.set(now.addingTimeInterval(30 * 24 * 60 * 60), forKey: Key.nextPrompt)
        }

        presentingWindowID = nil
    }
}
