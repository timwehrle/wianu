import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var showingAddSite = false

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
        .navigationTitle(model.selection == .home ? "Home" : "Wianu")
        .sheet(isPresented: $showingAddSite) {
            SiteEditorView(
                model: model,
                mode: .add
            )
        }
    }

    private func perform(_ action: CommandPaletteAction) {
        switch action {
        case let .openSite(siteID):
            model.select(.site(siteID))
        case let .continueWatching(itemID):
            model.select(.continueWatching(itemID))
        case .addSite:
            model.dismissCommandPalette()
            showingAddSite = true
        case .openSettings:
            model.dismissCommandPalette()
            openSettings()
        }
    }
}
