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
            .task(id: loadingIndicatorID) {
                await updateLoadingIndicator(for: session)
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
            sessionID: session.map(ObjectIdentifier.init),
            isBlocked: model.isCommandPalettePresented || model.selection == .home,
            url: session?.page.url
        )
    }

    var loadingIndicatorID: LoadingIndicatorID {
        LoadingIndicatorID(sessionID: session.map(ObjectIdentifier.init), isLoading: session?.page.isLoading)
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

    func updateLoadingIndicator(for session: BrowserSession?) async {
        guard let session, session.page.isLoading else {
            showsLoadingIndicator = false
            return
        }

        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled, session === sessions.active, session.page.isLoading else { return }
        showsLoadingIndicator = true
    }
}

private struct PageInteractionID: Hashable {
    let sessionID: ObjectIdentifier?
    let isBlocked: Bool
    let url: URL?
}

private struct LoadingIndicatorID: Hashable {
    let sessionID: ObjectIdentifier?
    let isLoading: Bool?
}
