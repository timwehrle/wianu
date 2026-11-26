import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct ContinueWatchingDOMTests {
        @Test
        func `Apple diagnostics include shelf cards without treating recommendations as a queue`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <base href="https://tv.apple.com/"><title>Apple TV</title>
            <div data-testid="section-container" id="shelf-one"><div data-testid="section-content">
                <div class="rich-lockup-shelf-header"><div class="header"><div class="header-title-wrapper">
                    <h2 data-testid="header-title">Continue Watching on Apple TV</h2>
                </div></div></div>
                <a data-testid="lockup" class="lockup" aria-label="A Show"
                    href="/us/episode/episode-one/umc.cmc.example?token=secret"><img alt="A Show"></a>
            </div></div>
            """], host: "tv.apple.com", adapter: .appleTV)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics != nil }

            let report = try #require(fixture.continueWatchingQueue.diagnostics)
            #expect(report.contains("shelf-one"))
            #expect(report.contains("umc.cmc.example"))
            #expect(report.contains("A Show"))
            #expect(!report.contains("secret"))
            #expect(fixture.continueWatchingQueue.updatedAt == nil)
        }
    }
}
