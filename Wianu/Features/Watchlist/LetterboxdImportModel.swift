import Foundation
import Observation

@MainActor
@Observable
final class LetterboxdImportModel {
    private(set) var isLoading = true
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    private(set) var currentTitle = ""
    private(set) var entries: [ImportReviewEntry] = []
    private(set) var skippedCount = 0
    private(set) var message: String?

    func load(from url: URL, existingItems: [WatchlistItem], client: TMDBClient) async {
        let hasAccess = url.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }

            isLoading = false
        }

        do {
            let result = try await Task.detached {
                try LetterboxdWatchlistImporter.importItems(contentsOf: url, maximumBytes: 10 * 1_048_576)
            }.value

            try Task.checkCancellation()

            let existingURLs = Set(existingItems.compactMap { $0.url.map(URLNormalizer.comparisonKey(for:)) })
            let pending = result.items.filter { item in
                guard let url = item.url else { return true }

                return !existingURLs.contains(URLNormalizer.comparisonKey(for: url))
            }

            skippedCount = result.skippedRowCount + result.items.count - pending.count
            totalCount = pending.count

            for item in pending {
                try Task.checkCancellation()
                currentTitle = item.title

                try await entries.append(match(item, client: client))
                completedCount += 1
            }

            try Task.checkCancellation()

            if entries.isEmpty {
                message = "No new films to import. \(skippedCount) entries skipped."
            }

        } catch {
            entries = []

            if !Task.isCancelled, !isCancellation(error) {
                message = error.localizedDescription
            }
        }
    }

    private func match(_ item: WatchlistItem, client: TMDBClient) async throws -> ImportReviewEntry {
        do {
            return try await LetterboxdMatcher.search(item, client: client)
        } catch {
            try Task.checkCancellation()

            if isCancellation(error) {
                throw CancellationError()
            }

            return ImportReviewEntry(
                item: item,
                candidates: [],
                classification: .ambiguous,
                error: error.localizedDescription
            )
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
