import SwiftUI
import WebKit

struct BrowserView: View {
    @Bindable var model: AppModel
    @State private var sessions: BrowserSessions
    @State private var isVideoInformationPresented = false
    @State private var showsLoadingIndicator = false

    init(model: AppModel) {
        self.model = model
        _sessions = State(initialValue: BrowserSessions(continueWatchingQueues: model.continueWatchingQueues))
    }

    var body: some View {
        browserContent
            .task(id: model.navigationRequest?.id) {
                guard let request = model.navigationRequest else {
                    sessions.pauseActive()
                    return
                }

                sessions.open(request)
            }
            .onDisappear {
                sessions.cancelNavigation()
            }
            .onChange(of: model.siteStore.sites) { _, sites in
                sessions.removeChangedSites(sites)
            }
            .task(id: pageInteractionID) {
                await session?.setPageInteractionBlocked(
                    model.isCommandPalettePresented || model.selection == .home
                )
            }
            .onChange(of: session?.page.url) { _, url in
                session?.videoDiagnostics.clear()
                model.activateSite(matching: url)
            }
            .focusedSceneValue(\.showVideoInformation) {
                isVideoInformationPresented = true
            }
            .sheet(isPresented: $isVideoInformationPresented) {
                if let session {
                    VideoInformationView(diagnostics: session.videoDiagnostics)
                }
            }
            .task(id: session?.page.isLoading) {
                await updateLoadingIndicator()
            }
            .toolbar {
                if let session, !model.isCommandPalettePresented, model.selection != .home {
                    BrowserToolbar(
                        model: model,
                        session: session,
                        showsLoadingIndicator: showsLoadingIndicator
                    )
                }
            }
            .alert(
                "Navigation Blocked",
                isPresented: blockedNavigationBinding
            ) {
                Button("OK") { session?.router.clearBlockedNavigationMessage() }
            } message: {
                Text(session?.router.blockedNavigationMessage ?? "")
            }
    }
}

private extension BrowserView {
    var session: BrowserSession? {
        sessions.active
    }

    @ViewBuilder
    var browserContent: some View {
        if model.selection == .home {
            HomeView(model: model)
        } else if model.navigationRequest != nil, let session {
            BrowserPaneView(page: session.page)
        } else {
            ContentUnavailableView(
                "No Site Selected",
                systemImage: "globe",
                description: Text("Select a site or a Continue Watching item.")
            )
        }
    }

    var pageInteractionID: PageInteractionID {
        PageInteractionID(
            isBlocked: model.isCommandPalettePresented || model.selection == .home,
            url: session?.page.url
        )
    }

    var blockedNavigationBinding: Binding<Bool> {
        Binding(
            get: { session?.router.blockedNavigationMessage != nil },
            set: { presented in
                if !presented {
                    session?.router.clearBlockedNavigationMessage()
                }
            }
        )
    }

    func updateLoadingIndicator() async {
        guard session?.page.isLoading == true else {
            showsLoadingIndicator = false
            return
        }

        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled, session?.page.isLoading == true else { return }
        showsLoadingIndicator = true
    }
}

private struct PageInteractionID: Hashable {
    let isBlocked: Bool
    let url: URL?
}

@MainActor
@Observable
final class BrowserSessions {
    private struct Entry {
        let siteID: SavedSite.ID?
        let siteURL: URL?
        let session: BrowserSession
    }

    private let continueWatchingQueues: [ContinueWatchingController]
    private var entries: [Entry] = []
    private(set) var active: BrowserSession?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    init(continueWatchingQueues: [ContinueWatchingController]) {
        self.continueWatchingQueues = continueWatchingQueues
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.discardInactive() }
        }
        source.resume()
        memoryPressureSource = source
    }

    func open(_ request: AppModel.NavigationRequest) {
        let site = request.site
        let existingIndex = entries.firstIndex { entry in
            guard let site else { return false }
            return entry.siteID == site.id && entry.siteURL == site.url
        }
        let entry: Entry
        let isExisting = existingIndex != nil

        if let existingIndex {
            entry = entries.remove(at: existingIndex)
        } else {
            let session = BrowserSession(continueWatchingQueues: continueWatchingQueues)
            entry = Entry(siteID: site?.id, siteURL: site?.url, session: session)
        }

        if active !== entry.session {
            active?.pausePlayback()
        }
        entry.session.cancelPendingPause()
        active = entry.session
        entries.append(entry)
        while entries.count > 3 {
            entries.removeFirst().session.cancelNavigation()
        }

        if !isExisting || request.intent == .navigate {
            entry.session.router.openDestination(request.url)
        }
    }

    func pauseActive() {
        active?.pausePlayback()
    }

    func cancelNavigation() {
        for entry in entries {
            entry.session.cancelNavigation()
        }
    }

    func removeChangedSites(_ sites: [SavedSite]) {
        let activeWasRemoved = entries.contains { entry in
            entry.session === active && entry.siteID != nil
                && !sites.contains { $0.id == entry.siteID && $0.url == entry.siteURL }
        }
        entries.removeAll { entry in
            guard let siteID = entry.siteID,
                  !sites.contains(where: { $0.id == siteID && $0.url == entry.siteURL }) else { return false }
            entry.session.cancelNavigation()
            return true
        }
        if activeWasRemoved {
            active?.pausePlayback()
            active = nil
        }
    }

    private func discardInactive() {
        entries.removeAll { entry in
            guard entry.session !== active else { return false }
            entry.session.cancelNavigation()
            return true
        }
    }
}
