import Foundation
import Observation

@MainActor
@Observable
final class ReleaseNotesModel {
    private(set) var presentingWindowID: UUID?
    private(set) var presentedNotes: [ReleaseNote] = []

    private let notes: [ReleaseNote]
    private let currentVersion: String
    private let defaults: UserDefaults
    private var prepared = false
    private static let acknowledgedVersionKey = "releaseNotesAcknowledgedVersion"

    init(
        notes: [ReleaseNote] = ReleaseNote.load(),
        currentVersion: String = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        defaults: UserDefaults = .standard
    ) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.notes = notes.filter { $0.version.compare(currentVersion, options: .numeric) != .orderedDescending }
            .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    var hasNotes: Bool {
        !notes.isEmpty
    }

    func prepare(isExistingUser: Bool) {
        guard !prepared else { return }

        prepared = true
        if defaults.string(forKey: Self.acknowledgedVersionKey) == nil, !isExistingUser {
            defaults.set(currentVersion, forKey: Self.acknowledgedVersionKey)
        }
    }

    func present(in windowID: UUID, automatically: Bool) {
        guard presentingWindowID == nil else { return }

        var available = notes
        if automatically {
            guard prepared else { return }

            if let acknowledged = defaults.string(forKey: Self.acknowledgedVersionKey) {
                available = notes.filter { $0.version.compare(acknowledged, options: .numeric) == .orderedDescending }
            } else {
                // Existing installations have no saved version when this feature first ships.
                available = notes.filter { $0.version == currentVersion }
            }
        }

        guard !available.isEmpty else { return }

        presentedNotes = available
        presentingWindowID = windowID
    }

    func dismiss(in windowID: UUID) {
        guard presentingWindowID == windowID else { return }

        let acknowledged = defaults.string(forKey: Self.acknowledgedVersionKey)
        if acknowledged == nil || currentVersion.compare(acknowledged ?? "", options: .numeric) == .orderedDescending {
            defaults.set(currentVersion, forKey: Self.acknowledgedVersionKey)
        }

        presentingWindowID = nil
        presentedNotes = []
    }
}
