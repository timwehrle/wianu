import Foundation

enum SidebarSelection: Hashable {
    case home
    case site(SavedSite.ID)
    case continueWatching(ContinueWatchingItem.ID)
    case watchlistItem(WatchlistItem.ID)
}
