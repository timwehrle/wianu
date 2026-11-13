import Foundation
import Observation
import WebKit

struct ContinueWatchingEntry: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let episodeTitle: String?
    let season: Int?
    let episode: Int?
    let url: URL
}

struct ContinueWatchingSnapshot: Codable {
    let entries: [ContinueWatchingEntry]
    let updatedAt: Date
}

private struct ContinueWatchingDiagnostics: Decodable {
    let diagnostics: String
}

private struct ContinueWatchingPayloadItem: Decodable {
    let id: String
    let title: String
    let episodeTitle: String?
    let season: Int?
    let episode: Int?
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
        guard let decoded = try? JSONDecoder().decode([ContinueWatchingPayloadItem].self, from: data),
              decoded.count <= 100,
              decoded.allSatisfy({ !$0.title.isEmpty && $0.title.count <= 500 })
        else {
            return nil
        }

        var seen: Set<String> = []
        var received: [ContinueWatchingEntry] = []

        for item in decoded {
            guard let destination = adapter.playbackURL(id: item.id, supplied: item.url) else {
                return nil
            }

            guard seen.insert(item.id).inserted else { continue }

            received.append(ContinueWatchingEntry(
                id: item.id,
                title: item.title,
                episodeTitle: item.episodeTitle,
                season: item.season,
                episode: item.episode,
                url: destination
            ))
        }

        return received
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
