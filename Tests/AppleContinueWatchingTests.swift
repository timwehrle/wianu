import Foundation
import Testing
@testable import Wianu

extension WebKitIntegrationTests {
    @Suite(.serialized)
    @MainActor
    struct AppleContinueWatchingTests {
        @Test
        func `Apple captures the static consumer identifier`() async throws {
            let fixture = VideoObserverFixture(
                pages: ["/": "<title>Apple TV</title>"], host: "tv.apple.com",
                pageScript: """
                globalThis.fetch = async () => new Response(JSON.stringify({ consumerIdList: [
                    { namespace: 'APPSTORE_ENGAGEMENT', consumerId: 'other' },
                    { namespace: 'APPSTORE_ENGAGEMENT_STATIC', consumerId: 'profile-one' }
                ] }));
                """, adapter: .appleTV
            )
            defer { fixture.stop() }

            try await fixture.load("/")
            _ = try await fixture.webView.evaluateJavaScript(
                "fetch('https://amp-account.tv.apple.com/account/v3/data'); void 0;"
            )
            try await fixture.waitUntil { fixture.continueWatchingQueue.profileID == "profile-one" }
        }

        @Test
        func `Apple reads structured continue watching shelf`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <script id="serialized-server-data" type="application/json">
            {"data":[{"data":{"shelves":[{"id":"uts.col.ChannelUpNext.tvs.sbd.4000","items":[{
              "$kind":"ContinueWatchingLockup","id":"umc.cmc.episode1","type":"Episode","title":"Severance",
              "progress":31,"segue":{"url":"https://tv.apple.com/de/episode/title/umc.cmc.episode1"},
              "playAction":{"contentDescriptor":{"items":[{"playable":{"canonicalMetadata":{
                "episodeTitle":"Fünf Fragen","seasonNumber":1,"episodeNumber":1
              }}}]}}
            }]}]}}]}
            </script>
            """], host: "tv.apple.com", adapter: .appleTV)
            defer { fixture.stop() }

            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.updatedAt != nil }
            let entry = try #require(fixture.continueWatchingQueue.entries.first)
            #expect(entry.title == "Severance")
            #expect(entry.episodeTitle == "Fünf Fragen")
            #expect(entry.season == 1)
            #expect(entry.episode == 1)
            #expect(entry.progress == 0.31)
        }

        @Test
        func `Apple preserves the saved queue for an incomplete shelf`() async throws {
            let fixture = VideoObserverFixture(pages: ["/": """
            <script id="serialized-server-data" type="application/json">
            {"data":{"shelves":[{"id":"uts.col.ChannelUpNext.tvs.sbd.4000","items":[
              {"$kind":"ContinueWatchingLockup","id":"umc.cmc.bad","title":"Incomplete"}
            ]}]}}
            </script>
            """], host: "tv.apple.com", adapter: .appleTV)
            defer { fixture.stop() }

            let source = try #require(URL(string: "https://tv.apple.com/"))
            fixture.continueWatchingQueue.receive(json: """
            [{"id":"umc.cmc.saved","title":"Saved","url":"https://tv.apple.com/us/show/saved/umc.cmc.saved"}]
            """, from: source)
            try await fixture.load("/")
            try await fixture.waitUntil { fixture.continueWatchingQueue.diagnostics != nil }
            #expect(fixture.continueWatchingQueue.entries.first?.title == "Saved")
        }
    }
}
