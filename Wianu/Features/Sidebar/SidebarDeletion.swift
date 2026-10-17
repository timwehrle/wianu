import Foundation

enum SidebarDeletion {
    case site(SavedSite)
    case continueWatching(ContinueWatchingItem)
    case watchlistItem(WatchlistItem)

    var title: String {
        switch self {
        case .site:
            "Delete Site?"
        case .continueWatching:
            "Remove from Continue Watching?"
        case .watchlistItem:
            "Remove from Watchlist?"
        }
    }

    var actionTitle: String {
        switch self {
        case .site:
            "Delete"
        case .continueWatching, .watchlistItem:
            "Remove"
        }
    }

    var message: String {
        switch self {
        case .site:
            "This removes the site and its Continue Watching entries from Wianu."
        case let .continueWatching(item):
            "“\(item.title)” will be removed."
        case let .watchlistItem(item):
            "“\(item.title)” will be removed."
        }
    }
}
