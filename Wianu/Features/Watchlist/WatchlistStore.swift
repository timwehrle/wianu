import Foundation
import Observation

@MainActor
@Observable
final class WatchlistStore {
    private(set) var items: [WatchlistItem] = []
    private(set) var persistenceError: String?

    @ObservationIgnored
    private let fileStore: JSONFileStore<[WatchlistItem]>

    init(
        fileStore: JSONFileStore<[WatchlistItem]> = JSONFileStore(
            fileName: "letterboxd-watchlist.json",
            folderName: "Wianu"
        )
    ) {
        self.fileStore = fileStore
        load()
    }

    func item(id: WatchlistItem.ID) -> WatchlistItem? {
        items.first { $0.id == id }
    }

    func item(matching url: URL) -> WatchlistItem? {
        let key = URLNormalizer.comparisonKey(for: url)
        return items.first {
            $0.url.map(URLNormalizer.comparisonKey(for:)) == key
        }
    }

    func contains(url: URL) -> Bool {
        item(matching: url) != nil
    }

    func replaceImportedItems(with newItems: [WatchlistItem]) {
        let existingIDs = items.reduce(into: [String: WatchlistItem.ID]()) {
            ids, item in
            guard item.source == .letterboxd, let url = item.url else { return }
            ids[URLNormalizer.comparisonKey(for: url)] = item.id
        }

        let importedItems = newItems.enumerated().map { index, item in
            WatchlistItem(
                id: item.url.flatMap {
                    existingIDs[URLNormalizer.comparisonKey(for: $0)]
                } ?? item.id,
                title: item.title,
                year: item.year,
                url: item.url,
                addedAt: item.addedAt,
                sourceOrder: index,
                source: .letterboxd
            )
        }
        let customItems = items
            .filter { $0.source == .custom }
            .enumerated()
            .map { offset, item in
                item.withSourceOrder(importedItems.count + offset)
            }

        items = importedItems + customItems
        persist()
    }

    func add(title: String, year: Int?, url: URL?) {
        items.append(
            WatchlistItem(
                title: title,
                year: year,
                url: url,
                addedAt: Date(),
                sourceOrder: items.count,
                source: .custom
            )
        )
        persist()
    }

    func update(
        id: WatchlistItem.ID,
        title: String,
        year: Int?,
        url: URL?
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index] = items[index].updating(title: title, year: year, url: url)
        persist()
    }

    func remove(id: WatchlistItem.ID) {
        items.removeAll { $0.id == id }
        items = items.enumerated().map {
            $0.element.withSourceOrder($0.offset)
        }
        persist()
    }

    private func load() {
        do {
            items = try fileStore.load(defaultValue: [])
                .sorted { $0.sourceOrder < $1.sourceOrder }
            persistenceError = nil
        } catch {
            items = []
            persistenceError = error.localizedDescription
        }
    }

    private func persist() {
        do {
            try fileStore.save(items)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}
