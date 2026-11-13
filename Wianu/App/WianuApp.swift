import SwiftUI

@main
struct WianuApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var updateService = UpdateService()
    @State private var model = AppModel()
    @State private var releaseNotes = ReleaseNotesModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, releaseNotes: releaseNotes)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            VideoInformationCommands()
            SearchCommands()
            WhatsNewCommands()

            CommandGroup(replacing: .appInfo) {
                Button("About Wianu") {
                    openWindow(id: "about")
                }
            }

            CommandGroup(after: .appInfo) {
                Button {
                    model.updateCheckStarted()
                    updateService.checkForUpdates()
                } label: {
                    Label(
                        "Check for Updates…",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(!updateService.canCheckForUpdates)
            }

            CommandGroup(after: .help) {
                Link(
                    "Send Feedback…",
                    destination: URL(
                        string: "https://github.com/timwehrle/Wianu/issues/new/choose"
                    )!
                )
            }
        }
        Settings {
            SettingsView(model: model)
        }

        Window("About Wianu", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
    }
}

struct SearchWianuKey: FocusedValueKey {
    typealias Value = @MainActor () -> Void
}

struct ShowVideoInformationKey: FocusedValueKey {
    typealias Value = @MainActor () -> Void
}

extension FocusedValues {
    var searchWianu: SearchWianuKey.Value? {
        get { self[SearchWianuKey.self] }
        set { self[SearchWianuKey.self] = newValue }
    }

    var showVideoInformation: ShowVideoInformationKey.Value? {
        get { self[ShowVideoInformationKey.self] }
        set { self[ShowVideoInformationKey.self] = newValue }
    }
}

private struct SearchCommands: Commands {
    @FocusedValue(\.searchWianu) private var searchWianu

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Search Wianu…") {
                searchWianu?()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(searchWianu == nil)
        }
    }
}

private struct VideoInformationCommands: Commands {
    @FocusedValue(\.showVideoInformation) private var showVideoInformation

    var body: some Commands {
        CommandMenu("Debug") {
            Button("Video Information…") {
                showVideoInformation?()
            }
            .disabled(showVideoInformation == nil)
        }
    }
}

struct ShowWhatsNewKey: FocusedValueKey {
    typealias Value = @MainActor () -> Void
}

extension FocusedValues {
    var showWhatsNew: ShowWhatsNewKey.Value? {
        get { self[ShowWhatsNewKey.self] }
        set { self[ShowWhatsNewKey.self] = newValue }
    }
}

private struct WhatsNewCommands: Commands {
    @FocusedValue(\.showWhatsNew) private var showWhatsNew

    var body: some Commands {
        CommandGroup(before: .help) {
            Button("What's New…") { showWhatsNew?() }
                .disabled(showWhatsNew == nil)
        }
    }
}
