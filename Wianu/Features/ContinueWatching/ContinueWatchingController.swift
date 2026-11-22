import Foundation
import Observation
import WebKit

struct ContinueWatchingEntry: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let episodeTitle: String?
    let season: Int?
    let episode: Int?
    let storeOffer: Bool?
    let progress: Double?
    let url: URL
}

struct ContinueWatchingSnapshot: Codable {
    let entries: [ContinueWatchingEntry]
    let updatedAt: Date
}

private struct ContinueWatchingDiagnostics: Decodable {
    let diagnostics: String
}

private struct ContinueWatchingPartialPayload: Decodable {
    let entries: [ContinueWatchingPayloadItem]
    let partial: Bool
}

private struct ContinueWatchingPayloadItem: Decodable {
    let id: String
    let title: String
    let episodeTitle: String?
    let season: Int?
    let episode: Int?
    let storeOffer: Bool?
    let progress: Double?
    // False means the reader could not determine the current episode; nil keeps legacy snapshot behavior.
    let episodeMetadataKnown: Bool?
    let url: URL?
}

@MainActor
@Observable
final class ContinueWatchingController: NSObject, WKScriptMessageHandler, Identifiable {
    let adapter: ContinueWatchingAdapter
    var id: ContinueWatchingService {
        adapter.id
    }

    private(set) var entries: [ContinueWatchingEntry] = []
    private(set) var updatedAt: Date?
    private(set) var responseError = false
    private(set) var refreshID: UUID?
    private(set) var diagnostics: String?
    private(set) var storageError = false

    private var handlerName: String {
        "continueWatching_" + id.rawValue
    }

    private let fileStore: JSONFileStore<ContinueWatchingSnapshot?>?
    private let refreshTimeout: Duration
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    init(
        adapter: ContinueWatchingAdapter,
        fileStore: JSONFileStore<ContinueWatchingSnapshot?>? = nil,
        refreshTimeout: Duration = .seconds(20)
    ) {
        self.adapter = adapter
        self.fileStore = fileStore
        self.refreshTimeout = refreshTimeout
        super.init()

        do {
            if let snapshot = try fileStore?.load(defaultValue: nil) {
                entries = snapshot.entries
                updatedAt = snapshot.updatedAt
            }
        } catch {
            storageError = true
        }
    }

    func install(in controller: WKUserContentController) {
        controller.add(self, contentWorld: .page, name: handlerName)
        controller.addUserScript(WKUserScript(
            source: adapter.observerScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        ))
    }

    func beginRefresh() {
        refreshTask?.cancel()
        responseError = false
        let id = UUID()
        refreshID = id
        let timeout = refreshTimeout

        refreshTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch { return }

            self?.finishRefreshIfWaiting(id)
        }
    }

    func finishRefreshIfWaiting(_ id: UUID) {
        guard refreshID == id else { return }

        endRefresh()
        responseError = true
    }

    private func endRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
    }

    func clear() {
        entries = []
        diagnostics = nil
        updatedAt = nil
        responseError = false
        endRefresh()

        saveSnapshot(nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == handlerName, message.frameInfo.isMainFrame, message.world == .page,
              let url = message.frameInfo.request.url,
              let json = message.body as? String
        else { return }

        receive(json: json, from: url)
    }

    func receive(json: String, from url: URL) {
        guard adapter.matches(url), json.utf8.count <= 128_000, let data = json.data(using: .utf8) else { return }

        if let report = try? JSONDecoder().decode(ContinueWatchingDiagnostics.self, from: data) {
            diagnostics = String(report.diagnostics.prefix(16000))
            return
        }

        guard let received = decodeEntries(from: data) else {
            responseError = true
            endRefresh()
            return
        }

        if entries != received {
            entries = received
        }

        let receivedAt = Date.now
        updatedAt = receivedAt
        responseError = false
        endRefresh()

        saveSnapshot(ContinueWatchingSnapshot(entries: received, updatedAt: receivedAt))
    }

    private func decodeEntries(from data: Data) -> [ContinueWatchingEntry]? {
        let decoder = JSONDecoder()
        let partialPayload = try? decoder.decode(ContinueWatchingPartialPayload.self, from: data)
        let partial = partialPayload?.partial == true
        let decoded = partial ? partialPayload?.entries : try? decoder.decode(
            [ContinueWatchingPayloadItem].self,
            from: data
        )

        guard let decoded, decoded.count <= 100,
              decoded.allSatisfy({ !$0.title.isEmpty && $0.title.count <= 500 })
        else {
            return nil
        }

        let previousEntries = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen: Set<String> = []
        var received: [ContinueWatchingEntry] = []

        for item in decoded {
            guard let destination = adapter.playbackURL(id: item.id, supplied: item.url) else {
                return nil
            }

            guard seen.insert(item.id).inserted else { continue }

            let previous = previousEntries[item.id]
            let preserveEpisode = item.episodeMetadataKnown == false
            let preserveProgress = id == .netflix || item.episodeMetadataKnown != nil
            let changedEpisode = item.episodeMetadataKnown == true
                && (item.season != previous?.season || item.episode != previous?.episode)

            received.append(ContinueWatchingEntry(
                id: item.id,
                title: item.title,
                episodeTitle: preserveEpisode ? previous?.episodeTitle : item.episodeTitle,
                season: preserveEpisode ? previous?.season : item.season,
                episode: preserveEpisode ? previous?.episode : item.episode,
                storeOffer: item.storeOffer,
                progress: item.progress.flatMap { (0 ... 1).contains($0) ? $0 : nil }
                    ?? (preserveProgress && !changedEpisode ? previous?.progress : nil),
                url: destination
            ))
        }

        guard partial else { return received }

        let updates = Dictionary(received.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existingIDs = Set(entries.map(\.id))
        let additions = received.filter { !existingIDs.contains($0.id) }.prefix(max(0, 100 - entries.count))
        return entries.map { updates[$0.id] ?? $0 } + additions
    }

    private func saveSnapshot(_ snapshot: ContinueWatchingSnapshot?) {
        do {
            try fileStore?.save(snapshot)
            storageError = false
        } catch {
            storageError = true
        }
    }
}
