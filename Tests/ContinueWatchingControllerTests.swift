import Foundation
import Testing
@testable import Wianu

@MainActor
struct ContinueWatchingControllerTests {
    @Test
    func `Refresh times out without a sidebar view`() async throws {
        let controller = ContinueWatchingController(adapter: .netflix, refreshTimeout: .zero)
        controller.beginRefresh()

        for _ in 0 ..< 100 {
            if controller.refreshID == nil {
                break
            }

            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(controller.refreshID == nil)
        #expect(controller.responseError)
    }

    @Test
    func `Successful responses and clearing cancel pending refresh timeouts`() async throws {
        let controller = ContinueWatchingController(adapter: .netflix, refreshTimeout: .zero)
        let url = try #require(URL(string: "https://www.netflix.com/browse"))

        controller.beginRefresh()
        controller.receive(json: "[]", from: url)
        try await Task.sleep(for: .milliseconds(10))

        #expect(controller.refreshID == nil)
        #expect(!controller.responseError)

        controller.beginRefresh()
        controller.clear()
        try await Task.sleep(for: .milliseconds(10))

        #expect(controller.refreshID == nil)
        #expect(!controller.responseError)
    }

    @Test
    func `Saved queues survive restart and failed refreshes`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = JSONFileStore<ContinueWatchingSnapshot?>(
            fileName: "netflix.json", folderName: "queues", baseDirectory: directory
        )
        let url = try #require(URL(string: "https://www.netflix.com/browse"))
        let controller = ContinueWatchingController(adapter: .netflix, fileStore: store)
        controller.receive(
            json: """
            [{"id":"123","title":"A Show","url":"https://www.netflix.com/watch/123"}]
            """,
            from: url
        )

        let restored = ContinueWatchingController(adapter: .netflix, fileStore: store)
        #expect(restored.entries == controller.entries)
        #expect(restored.updatedAt != nil)
        #expect(!restored.storageError)

        restored.receive(json: "invalid", from: url)
        restored.beginRefresh()
        try restored.finishRefreshIfWaiting(#require(restored.refreshID))

        let afterFailure = ContinueWatchingController(adapter: .netflix, fileStore: store)
        #expect(afterFailure.entries == controller.entries)

        restored.receive(json: "[]", from: url)

        let empty = ContinueWatchingController(adapter: .netflix, fileStore: store)
        #expect(empty.entries.isEmpty)
        #expect(empty.updatedAt != nil)

        empty.clear()
        let cleared = ContinueWatchingController(adapter: .netflix, fileStore: store)
        #expect(cleared.updatedAt == nil)
    }

    @Test
    func `Unreadable saved queues recover after a successful refresh`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = JSONFileStore<ContinueWatchingSnapshot?>(
            fileName: "netflix.json", folderName: "queues", baseDirectory: directory
        )
        try store.save(nil)
        try Data("invalid".utf8).write(to: directory.appending(path: "queues/netflix.json"))

        let controller = ContinueWatchingController(adapter: .netflix, fileStore: store)
        #expect(controller.entries.isEmpty)
        #expect(controller.storageError)

        try controller.receive(json: "[]", from: #require(URL(string: "https://www.netflix.com/browse")))

        #expect(!controller.storageError)
        #expect(try store.load(defaultValue: nil)?.entries.isEmpty == true)
    }

    @Test
    func `Each adapter has an independent queue and rejects destinations on another service`() throws {
        let netflix = ContinueWatchingController(adapter: .netflix)
        let prime = ContinueWatchingController(adapter: .primeVideo)
        let netflixURL = try #require(URL(string: "https://www.netflix.com/browse"))
        let primeURL = try #require(URL(string: "https://www.primevideo.com/"))
        let snapshot = """
        [{"id":"123","title":"A Show","url":"https://www.netflix.com/watch/123"}]
        """

        netflix.receive(json: snapshot, from: netflixURL)
        prime.receive(json: snapshot, from: primeURL)

        #expect(netflix.entries.count == 1)
        #expect(prime.entries.isEmpty)
        #expect(prime.responseError)
        #expect(prime.updatedAt == nil)
    }

    @Test
    func `Refresh locations are provider-specific and remove player query parameters`() throws {
        let netflix = try #require(URL(string: "https://www.netflix.com/watch/123?track=1"))
        let disney = try #require(URL(string: "https://www.disneyplus.com/play/123"))
        let prime = try #require(URL(string: "https://www.amazon.de/gp/video/detail/B00ABC"))

        #expect(ContinueWatchingAdapter.netflix.refreshURL(for: netflix)?
            .absoluteString == "https://www.netflix.com/browse")
        #expect(ContinueWatchingAdapter.disneyPlus.refreshURL(for: disney)?.path == "/home")
        #expect(ContinueWatchingAdapter.primeVideo.refreshURL(for: prime)?.path == "/gp/video/storefront")
        #expect(!ContinueWatchingAdapter.netflix.matches(URL(string: "https://netflix.com.evil.example/")))
    }

    @Test
    func `Refresh completion cancels the waiting state and stale timeouts do not change the queue`() throws {
        let controller = ContinueWatchingController(adapter: .hboMax)
        let url = try #require(URL(string: "https://www.hbomax.com/"))

        controller.beginRefresh()
        let oldRefresh = try #require(controller.refreshID)
        controller.beginRefresh()
        controller.finishRefreshIfWaiting(oldRefresh)

        #expect(controller.refreshID != nil)
        #expect(!controller.responseError)

        controller.receive(json: "[]", from: url)

        #expect(controller.refreshID == nil)
        #expect(controller.updatedAt != nil)

        controller.beginRefresh()
        let currentRefresh = try #require(controller.refreshID)
        controller.finishRefreshIfWaiting(currentRefresh)

        #expect(controller.responseError)
        #expect(controller.refreshID == nil)
        #expect(controller.updatedAt != nil)
    }

    @Test
    func `Provider queue preserves order and removes repeated video identities`() throws {
        let controller = ContinueWatchingController(adapter: .hboMax)
        let url = try #require(URL(string: "https://www.hbomax.com/"))
        let entry = """
        {"id":"00000000-0000-0000-0000-000000000001","title":"A Show",
         "episodeTitle":"The Next Episode","season":2,"episode":3}
        """

        controller.receive(json: "[\(entry),\(entry)]", from: url)

        #expect(controller.entries.count == 1)
        #expect(controller.entries.first?.episode == 3)
        #expect(controller.entries.first?.url.path == "/video/watch/00000000-0000-0000-0000-000000000001")
        #expect(controller.updatedAt != nil)
    }

    @Test
    func `Unknown responses preserve the previous queue and signal failure`() throws {
        let controller = ContinueWatchingController(adapter: .hboMax)
        let url = try #require(URL(string: "https://www.hbomax.com/"))

        controller.receive(json: "[]", from: url)
        controller.receive(json: "{\"unexpected\":true}", from: url)

        #expect(controller.responseError)
        #expect(controller.updatedAt != nil)

        controller.clear()

        #expect(controller.updatedAt == nil)
        #expect(!controller.responseError)
    }

    @Test(arguments: ["https://hbomax.com.evil.example/", "https://other.example/"])
    func `Other sites cannot publish a provider queue`(source: String) throws {
        let controller = ContinueWatchingController(adapter: .hboMax)
        let url = try #require(URL(string: source))

        controller.receive(json: "[]", from: url)

        #expect(controller.updatedAt == nil)
    }
}
