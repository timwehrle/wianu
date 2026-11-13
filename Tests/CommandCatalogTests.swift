import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Command catalog")
struct CommandCatalogTests {
    @Test
    func `Empty query shows core commands and the first five synced entries`() throws {
        let site = SavedSite(name: "Netflix", urlString: "https://netflix.com")
        let queue = ContinueWatchingController(adapter: .netflix)
        let source = try #require(URL(string: "https://www.netflix.com/browse"))
        let items = (0 ..< 7).map { index in
            ["id": String(index), "title": "Show \(index)", "url": "https://www.netflix.com/watch/\(index)"]
        }
        let data = try JSONSerialization.data(withJSONObject: items)
        let json = try #require(String(data: data, encoding: .utf8))
        queue.receive(json: json, from: source)

        let commands = CommandCatalog.commands(
            matching: "",
            sites: [site],
            continueWatchingQueues: [queue]
        )

        #expect(commands.contains { $0.action == .addSite })
        #expect(commands.contains { $0.action == .openSettings })
        #expect(commands.contains { $0.action == .openSite(site.id) })
        #expect(commands.filter {
            if case .continueWatching = $0.action {
                return true
            }

            return false
        }.count == 5)
        #expect(commands.last?.title == "Continue Show 4")
        #expect(commands.last?.action == .continueWatching(.netflix, "4"))
        #expect(commands.last?.subtitle == "Netflix")
    }

    @Test
    func `Matching ignores case and diacritics`() {
        let site = SavedSite(name: "Mubi Café", urlString: "https://mubi.com")
        let commands = CommandCatalog.commands(
            matching: "CAFE",
            sites: [site],
            continueWatchingQueues: []
        )

        #expect(commands.first?.action == .openSite(site.id))
    }
}
