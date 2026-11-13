import Foundation

enum SidebarDeletion {
    case site(SavedSite)
    case watchlistItem(WatchlistItem)

    var title: String {
        switch self {
        case .site:
            "Delete Site?"
        case .watchlistItem:
            "Remove from Watchlist?"
        }
    }

    var actionTitle: String {
        switch self {
        case .site:
            "Delete"
        case .watchlistItem:
            "Remove"
        }
    }

    var message: String {
        switch self {
        case .site:
            "This removes the site from Wianu."
        case let .watchlistItem(item):
            "“\(item.title)” will be removed."
        }
    }
}
