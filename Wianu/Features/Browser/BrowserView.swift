import SwiftUI
import WebKit

struct BrowserView: View {
    @Bindable var model: AppModel
    @State private var session: BrowserSession
    @State private var isVideoInformationPresented = false
    @State private var showsLoadingIndicator = false

    init(model: AppModel) {
        self.model = model
        _session = State(initialValue: BrowserSession())
    }

    var body: some View {
        browserContent
            .task(id: model.navigationRequest?.id) {
                guard let url = model.navigationRequest?.url else { return }
                session.router.openDestination(url)
            }
            .onChange(of: session.router.request?.id, initial: true) {
                session.startQueuedNavigation()
            }
            .onDisappear {
                session.cancelNavigation()
            }
            .task(id: pageInteractionID) {
                await session.setPageInteractionBlocked(
                    model.isCommandPalettePresented
                )
            }
            .onChange(of: session.page.url) { _, url in
                session.videoDiagnostics.clear()
                model.activateSite(matching: url)
            }
            .focusedSceneValue(\.showVideoInformation) {
                isVideoInformationPresented = true
            }
            .sheet(isPresented: $isVideoInformationPresented) {
                VideoInformationView(diagnostics: session.videoDiagnostics)
            }
            .task(id: session.page.isLoading) {
                await updateLoadingIndicator()
            }
            .toolbar {
                if !model.isCommandPalettePresented {
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
                Button("OK", action: session.router.clearBlockedNavigationMessage)
            } message: {
                Text(session.router.blockedNavigationMessage ?? "")
            }
    }
}

private extension BrowserView {
    @ViewBuilder
    var browserContent: some View {
        if model.navigationRequest != nil {
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
            isBlocked: model.isCommandPalettePresented,
            url: session.page.url
        )
    }

    var blockedNavigationBinding: Binding<Bool> {
        Binding(
            get: { session.router.blockedNavigationMessage != nil },
            set: { presented in
                if !presented {
                    session.router.clearBlockedNavigationMessage()
                }
            }
        )
    }

    func updateLoadingIndicator() async {
        guard session.page.isLoading else {
            showsLoadingIndicator = false
            return
        }

        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled, session.page.isLoading else { return }
        showsLoadingIndicator = true
    }
}

private struct PageInteractionID: Hashable {
    let isBlocked: Bool
    let url: URL?
}
