import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Release notes")
struct ReleaseNotesTests {
    private func withDefaults(_ test: (UserDefaults) throws -> Void) throws {
        let suite = "ReleaseNotesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        try test(defaults)
    }

    private let notes = ["1.9.0", "1.10.0", "1.8.0", "2.0.0"].map {
        ReleaseNote(version: $0, changes: [])
    }

    @Test
    func `fresh install skips popup but allows manual opening`() throws {
        try withDefaults { defaults in
            let model = ReleaseNotesModel(notes: notes, currentVersion: "1.10.0", defaults: defaults)
            let window = UUID()
            model.prepare(isExistingUser: false)
            model.present(in: window, automatically: true)
            #expect(model.presentingWindowID == nil)

            model.present(in: window, automatically: false)
            #expect(model.presentedNotes.map(\.version) == ["1.10.0", "1.9.0", "1.8.0"])
        }
    }

    @Test
    func `existing install shows current release once across windows and launches`() throws {
        try withDefaults { defaults in
            let model = ReleaseNotesModel(notes: notes, currentVersion: "1.10.0", defaults: defaults)
            let window = UUID()
            model.prepare(isExistingUser: true)
            model.present(in: window, automatically: true)
            model.present(in: UUID(), automatically: true)
            #expect(model.presentingWindowID == window)
            #expect(model.presentedNotes.map(\.version) == ["1.10.0"])

            model.dismiss(in: UUID())
            #expect(model.presentingWindowID == window)
            model.dismiss(in: window)

            let relaunched = ReleaseNotesModel(notes: notes, currentVersion: "1.10.0", defaults: defaults)
            relaunched.prepare(isExistingUser: true)
            relaunched.present(in: window, automatically: true)
            #expect(relaunched.presentingWindowID == nil)
        }
    }

    @Test
    func `skipped updates show unseen releases in numeric order`() throws {
        try withDefaults { defaults in
            let previous = ReleaseNotesModel(notes: notes, currentVersion: "1.8.0", defaults: defaults)
            previous.prepare(isExistingUser: false)

            let updated = ReleaseNotesModel(notes: notes, currentVersion: "1.10.0", defaults: defaults)
            updated.prepare(isExistingUser: true)
            updated.present(in: UUID(), automatically: true)
            #expect(updated.presentedNotes.map(\.version) == ["1.10.0", "1.9.0"])
        }
    }

    @Test
    func `bundled notes decode`() {
        let notes = ReleaseNote.load(bundle: Bundle.main)
        #expect(!notes.isEmpty)
        #expect(Set(notes.map(\.version)).count == notes.count)
        #expect(notes.allSatisfy { !$0.changes.isEmpty })
    }
}
