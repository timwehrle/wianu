import Foundation

enum SidebarSelection: Hashable {
    case home
    case site(SavedSite.ID)
    case continueWatching(ContinueWatchingService, String)
    case watchlistItem(WatchlistItem.ID)
}
