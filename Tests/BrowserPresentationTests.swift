import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Browser presentation")
struct BrowserPresentationTests {
    @Test func `normalizes page titles`() {
        #expect(BrowserPageMetadata.normalizedTitle("  Movie  ") == "Movie")
        #expect(BrowserPageMetadata.normalizedTitle(" \n ") == nil)
    }

    @Test func `builds a site home URL`() throws {
        let pageURL = try #require(
            URL(string: "https://example.com/watch/movie?id=42#player")
        )

        #expect(
            BrowserPageMetadata.homeURL(for: pageURL)
                == URL(string: "https://example.com/")
        )
    }

    @Test func `reloads when the page is idle`() {
        let session = BrowserSession()

        #expect(!session.page.isLoading)
        session.reloadOrStop()

        guard case .reload = session.router.request?.action else {
            Issue.record("Expected an idle page to queue a reload")
            return
        }
    }
}

@MainActor
@Suite("Home shelf scrolling")
struct HomeShelfScrollingTests {
    @Test func `short shelves cannot scroll past their content`() {
        let metrics = HomeShelfScrollMetrics(offset: 0, viewportWidth: 1000, contentWidth: 464)
        #expect(metrics.maximumOffset == 0)
        #expect(metrics.destination(direction: 1) == 0)
        #expect(metrics.destination(direction: -1) == 0)
    }

    @Test func `paging reaches both ends without overshooting`() {
        let nearEnd = HomeShelfScrollMetrics(offset: 1900, viewportWidth: 800, contentWidth: 3000)
        #expect(nearEnd.destination(direction: 1) == nearEnd.maximumOffset)
        let nearStart = HomeShelfScrollMetrics(offset: 100, viewportWidth: 800, contentWidth: 3000)
        #expect(nearStart.destination(direction: -1) == 0)
    }

    @Test func `resizing the window keeps paging inside the new bounds`() {
        let resized = HomeShelfScrollMetrics(offset: 2200, viewportWidth: 1400, contentWidth: 3000)
        #expect(resized.destination(direction: 1) <= resized.maximumOffset)
        #expect(resized.destination(direction: -1) >= 0)
    }
}

@MainActor
@Suite("Welcome service presets")
struct WelcomeServicePresetTests {
    @Test func `provider associations survive saving and reopening sites`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileStore = JSONFileStore<[SavedSite]>(
            fileName: "sites.json", folderName: "Tests", baseDirectory: directory
        )
        let store = SiteStore(fileStore: fileStore)
        for service in WelcomeView.services {
            store.addSite(service)
        }

        let restored = SiteStore(fileStore: fileStore)
        #expect(restored.sites.count == 4)
        for site in restored.sites {
            let provider = try #require(site.tmdbProviders.first)
            let expectedID: Int? = ["Netflix": 8, "Disney+": 337, "Prime Video": 9, "Apple TV": 350][site.name]
            #expect(provider.id == expectedID)
            #expect(SiteDraft(site: site).tmdbProviders == [provider])
        }
    }
}
