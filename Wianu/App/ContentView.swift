import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel
    let releaseNotes: ReleaseNotesModel
    let supportPrompt: SupportPromptModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openSettings) private var openSettings
    @State private var showingAddSite = false
    @State private var windowID = UUID()
    @AppStorage("hasDismissedWelcome") private var hasDismissedWelcome = false

    private var canShowReleaseNotes: Bool {
        !showingAddSite && !model.isCommandPalettePresented
            && supportPrompt.presentingWindowID == nil
            && (hasDismissedWelcome || !model.siteStore.sites.isEmpty)
    }

    private var showingReleaseNotes: Binding<Bool> {
        Binding(
            get: { releaseNotes.presentingWindowID == windowID },
            set: {
                if !$0 {
                    releaseNotes.dismiss(in: windowID)
                }
            }
        )
    }

    private var canShowSupportPrompt: Bool {
        scenePhase == .active && model.selection == .home && canShowReleaseNotes
            && releaseNotes.presentingWindowID == nil
    }

    private var showingSupportPrompt: Binding<Bool> {
        Binding(
            get: { supportPrompt.presentingWindowID == windowID },
            set: {
                if !$0 {
                    if supportPrompt.presentingWindowID == windowID {
                        model.supportPromptDismissed(permanently: false)
                    }
                    supportPrompt.dismiss(in: windowID)
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                model: model,
                showingAddSite: $showingAddSite
            )
        } detail: {
            ZStack {
                BrowserView(model: model)
                    .accessibilityHidden(model.isCommandPalettePresented)

                if model.isCommandPalettePresented {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.dismissCommandPalette()
                        }

                    CommandPaletteView(
                        model: model,
                        onAction: perform,
                        onDismiss: model.dismissCommandPalette
                    )
                    .frame(maxWidth: 640, maxHeight: 500)
                    .padding(32)
                }
            }
        }
        .task {
            releaseNotes.prepare(isExistingUser: hasDismissedWelcome || !model.siteStore.sites.isEmpty)
            presentReleaseNotesIfNeeded()
            presentSupportPromptIfNeeded()
        }
        .onDisappear {
            releaseNotes.dismiss(in: windowID)
            supportPrompt.dismiss(in: windowID)
        }
        .onChange(of: scenePhase) { _, _ in presentSupportPromptIfNeeded() }
        .onChange(of: model.selection) { _, _ in presentSupportPromptIfNeeded() }
        .sheet(isPresented: showingSupportPrompt) {
            SupportPromptView(
                onShown: model.supportPromptShown,
                onSupport: model.supportPromptClicked,
                onChoice: model.supportPromptDismissed
            ) { permanently in
                supportPrompt.dismiss(in: windowID, permanently: permanently)
            }
        }
        .onChange(of: model.isCommandPalettePresented) { _, isPresented in
            if !isPresented {
                presentReleaseNotesIfNeeded()
                presentSupportPromptIfNeeded()
            }
        }
        .onChange(of: canShowReleaseNotes) { _, _ in presentReleaseNotesIfNeeded() }
        .focusedSceneValue(\.showWhatsNew, canShowReleaseNotes && releaseNotes.hasNotes ? {
            releaseNotes.present(in: windowID, automatically: false)
        } : nil)
        .sheet(isPresented: showingReleaseNotes, onDismiss: presentSupportPromptIfNeeded) {
            WhatsNewView(notes: releaseNotes.presentedNotes)
        }
        .navigationTitle(model.selection == .home ? "Home" : "Wianu")
        .focusedSceneValue(\.searchWianu) {
            model.showCommandPalette()
        }
        .sheet(isPresented: $showingAddSite, onDismiss: presentSupportPromptIfNeeded) {
            SiteEditorView(
                model: model,
                mode: .add
            )
        }
    }

    private func presentSupportPromptIfNeeded() {
        guard scenePhase == .active else { return }

        supportPrompt.recordSession()
        guard canShowSupportPrompt else { return }

        supportPrompt.presentIfNeeded(in: windowID)
    }

    private func presentReleaseNotesIfNeeded() {
        guard canShowReleaseNotes else { return }

        releaseNotes.present(in: windowID, automatically: true)
    }

    private func perform(_ action: CommandPaletteAction) {
        switch action {
        case let .openSite(siteID):
            model.select(.site(siteID))
        case let .continueWatching(service, itemID):
            model.select(.continueWatching(service, itemID))
        case .addSite:
            model.dismissCommandPalette()
            showingAddSite = true
        case .openSettings:
            model.dismissCommandPalette()
            openSettings()
        }
    }
}
