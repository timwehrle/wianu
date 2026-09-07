import SwiftUI
import WebKit

struct BrowserToolbar: ToolbarContent {
    @Bindable var model: AppModel
    let session: BrowserSession
    let showsLoadingIndicator: Bool

    var body: some ToolbarContent {
        navigationItems
        browserTitleItem
        watchlistItem
        continueWatchingItem
        commandPaletteItem
    }
}

private extension BrowserToolbar {
    var navigationItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: session.goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(session.backItem == nil)
            .help("Go Back")
            .keyboardShortcut("[", modifiers: .command)

            Button(action: session.goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(session.forwardItem == nil)
            .help("Go Forward")
            .keyboardShortcut("]", modifiers: .command)

            Button {
                session.reloadOrStop()
            } label: {
                Image(systemName: reloadSystemImage)
            }
            .help(reloadLabel)
            .accessibilityLabel(reloadLabel)
            .disabled(session.page.url == nil && !showsLoadingIndicator)
            .keyboardShortcut("r", modifiers: .command)

            Button(action: goHome) {
                Image(systemName: "house")
            }
            .disabled(homeURL == nil)
            .help("Go to Site Home")
        }
    }

    var browserTitleItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if model.destinationURL != nil {
                BrowserTitleView(
                    title: displayedTitle,
                    url: session.page.url
                )
            }
        }
    }

    var watchlistItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: toggleWatchlist) {
                Image(
                    systemName: currentPageIsOnWatchlist
                        ? "bookmark.fill"
                        : "bookmark"
                )
            }
            .disabled(!canSaveCurrentPage)
            .help(
                currentPageIsOnWatchlist
                    ? "Remove from Watchlist"
                    : "Add to Watchlist"
            )
        }
    }

    var continueWatchingItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: toggleContinueWatching) {
                Image(
                    systemName: currentPageIsSaved
                        ? "play.rectangle.fill"
                        : "play.rectangle"
                )
            }
            .disabled(!canSaveCurrentPage)
            .help(
                currentPageIsSaved
                    ? "Remove from Continue Watching"
                    : "Save to Continue Watching"
            )
        }
    }

    var commandPaletteItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.showCommandPalette()
            } label: {
                Label("Command Palette", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("k", modifiers: .command)
            .help("Search Actions, Movies, and TV Shows")
        }
    }

    var reloadSystemImage: String {
        showsLoadingIndicator ? "xmark" : "arrow.clockwise"
    }

    var reloadLabel: String {
        showsLoadingIndicator ? "Stop Loading" : "Reload"
    }

    var displayedTitle: String {
        pageTitle ?? fallbackTitle
    }

    var fallbackTitle: String {
        model.selectedContinueWatchingItem?.title
            ?? model.selectedSite?.name
            ?? "Wianu"
    }

    var canSaveCurrentPage: Bool {
        session.page.url != nil && pageTitle != nil
    }

    var pageTitle: String? {
        BrowserPageMetadata.normalizedTitle(session.page.title)
    }

    var currentPageIsSaved: Bool {
        guard let url = session.page.url else { return false }
        return model.continueWatchingStore.contains(url: url)
    }

    var currentPageIsOnWatchlist: Bool {
        guard let url = session.page.url else { return false }
        return model.watchlistStore.contains(url: url)
    }

    var homeURL: URL? {
        if let siteURL = model.selectedSite?.url {
            return siteURL
        }

        return BrowserPageMetadata.homeURL(for: session.page.url)
    }

    func goHome() {
        guard let homeURL else { return }
        session.router.openInCurrentPage(URLRequest(url: homeURL))
    }

    func toggleContinueWatching() {
        guard let url = session.page.url, let pageTitle else { return }
        model.toggleContinueWatching(title: pageTitle, url: url)
    }

    func toggleWatchlist() {
        guard let url = session.page.url, let pageTitle else { return }
        model.toggleWatchlist(title: pageTitle, url: url)
    }
}

enum BrowserPageMetadata {
    static func normalizedTitle(_ title: String) -> String? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    static func homeURL(for url: URL?) -> URL? {
        guard let url,
              var components = URLComponents(
                  url: url,
                  resolvingAgainstBaseURL: false
              )
        else { return nil }

        components.path = "/"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
