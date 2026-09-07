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
