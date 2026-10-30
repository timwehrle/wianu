import Foundation
import Observation

@MainActor
@Observable
final class MediaIdentificationCoordinator {
    private(set) var results: [MediaIdentificationTarget: MediaIdentificationResult] = [:]
    private(set) var errors: [MediaIdentificationTarget: String] = [:]

    @ObservationIgnored private let watchlist: WatchlistStore
    @ObservationIgnored private let continueWatching: ContinueWatchingStore
    @ObservationIgnored private let service: MediaIdentificationService
    @ObservationIgnored private var tasks: [MediaIdentificationTarget: PendingTask] = [:]

    private struct PendingTask {
        let id: UUID
        let task: Task<Void, Never>
    }

    init(watchlist: WatchlistStore, continueWatching: ContinueWatchingStore, client: TMDBClient) {
        self.watchlist = watchlist
        self.continueWatching = continueWatching
        service = MediaIdentificationService(client: client)
    }

    func query(for target: MediaIdentificationTarget) -> MediaIdentificationQuery? {
        switch target {
        case let .watchlist(id):
            guard let item = watchlist.item(id: id) else {
                return nil
            }

            return .savedTitle(
                item.title, year: item.year, mediaType: item.source == .letterboxd ? .movie : nil, url: item.url
            )
        case let .continueWatching(id):
            guard let item = continueWatching.item(id: id) else {
                return nil
            }

            return .savedTitle(item.title, url: item.url)
        }
    }

    func metadata(for target: MediaIdentificationTarget) -> TMDBMediaResult? {
        switch target {
        case let .watchlist(id): watchlist.item(id: id)?.tmdbMetadata
        case let .continueWatching(id): continueWatching.item(id: id)?.tmdbMetadata
        }
    }

    func isIdentified(_ target: MediaIdentificationTarget) -> Bool {
        switch target {
        case let .watchlist(id): watchlist.item(id: id)?.tmdbID != nil
        case let .continueWatching(id): continueWatching.item(id: id)?.tmdbID != nil
        }
    }

    func needsReview(_ target: MediaIdentificationTarget) -> Bool {
        !isIdentified(target) && (results[target] != nil || errors[target] != nil)
    }

    func identifyInBackground(_ target: MediaIdentificationTarget) {
        cancel(target)

        guard !isIdentified(target), let query = query(for: target), !query.title.isEmpty else {
            return
        }

        if let shared = sharedMetadata(for: target), query.mediaType == nil || shared.mediaType == query.mediaType {
            associate(shared, with: target)
            return
        }

        let token = UUID()
        let task = Task {
            defer {
                if tasks[target]?.id == token {
                    tasks[target] = nil
                }
            }

            do {
                let result = try await service.search(query)
                try Task.checkCancellation()
                // Saved entries may be edited, removed, or confirmed while a request is in flight.
                guard tasks[target]?.id == token, self.query(for: target) == query,
                      !isIdentified(target)
                else {
                    return
                }

                results[target] = result

                if let match = result.match {
                    associate(match, with: target)
                }
            } catch {
                guard !Task.isCancelled, tasks[target]?.id == token, self.query(for: target) == query else {
                    return
                }

                errors[target] = error.localizedDescription
            }
        }

        tasks[target] = PendingTask(id: token, task: task)
    }

    func associate(_ media: TMDBMediaResult?, with target: MediaIdentificationTarget) {
        cancel(target)

        switch target {
        case let .watchlist(id): watchlist.associate(id: id, with: media)
        case let .continueWatching(id): continueWatching.associate(id: id, with: media)
        }
    }

    func cancel(_ target: MediaIdentificationTarget, clearResult: Bool = true) {
        tasks.removeValue(forKey: target)?.task.cancel()

        if clearResult {
            results[target] = nil
            errors[target] = nil
        }
    }

    private func sharedMetadata(for target: MediaIdentificationTarget) -> TMDBMediaResult? {
        switch target {
        case let .watchlist(id):
            guard let url = watchlist.item(id: id)?.url else {
                return nil
            }

            return continueWatching.item(matching: url)?.tmdbMetadata
        case let .continueWatching(id):
            guard let url = continueWatching.item(id: id)?.url else {
                return nil
            }

            return watchlist.item(matching: url)?.tmdbMetadata
        }
    }
}
