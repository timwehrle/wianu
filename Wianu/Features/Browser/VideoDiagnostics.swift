import Foundation
import Observation
import WebKit

struct VideoDiagnostic: Decodable, Identifiable {
    let id: String
    let videoWidth: Int
    let videoHeight: Int
    let displayWidth: Double
    let displayHeight: Double
    let paused: Bool
    let ended: Bool
    let seeking: Bool
    let readyState: Int
    let currentTime: Double
    let duration: Double?
    let bufferedAhead: Double
    let droppedFrames: Int?
    let totalFrames: Int?
    let sourceDescription: String?
    let sourceType: String?

    var playbackState: String {
        if ended {
            return "Ended"
        }
        if seeking || (!paused && readyState < 3) {
            return "Buffering"
        }
        return paused ? "Paused" : "Playing"
    }

    var isPlaying: Bool {
        !paused && !ended
    }

    var decodedArea: Int {
        videoWidth * videoHeight
    }

    var displayArea: Double {
        displayWidth * displayHeight
    }
}

struct PlaybackPageTitle: Equatable {
    let title: String
    let url: URL
}

private struct VideoFrameReport: Decodable {
    let frameID: String
    let videos: [VideoDiagnostic]
    let pageURL: URL?
    let title: String?
    let mediaTitle: String?
    let linkedURL: URL?
    let linkedTitle: String?
}

@MainActor
@Observable
final class VideoDiagnosticsController: NSObject, WKScriptMessageHandler {
    private struct FrameVideos {
        let videos: [VideoDiagnostic]
        let receivedAt: Date
    }

    private static let handlerName = "videoDiagnostics"
    private static let staleInterval: TimeInterval = 3
    private static let contentWorld = WKContentWorld.world(
        name: "WianuVideoDiagnostics"
    )

    private var frames: [String: FrameVideos] = [:]
    private(set) var pageURL: URL?
    private(set) var pageTitle: String?
    private(set) var mediaTitle: String?

    /// Keep the clicked title across navigation into the provider's player.
    private(set) var linkedTitle: PlaybackPageTitle?

    var videos: [VideoDiagnostic] {
        frames.values.flatMap(\.videos)
    }

    var selectedVideo: VideoDiagnostic? {
        videos.max { lhs, rhs in
            let lhsRank = (
                lhs.isPlaying ? 1 : 0,
                lhs.decodedArea,
                lhs.displayArea
            )
            let rhsRank = (
                rhs.isPlaying ? 1 : 0,
                rhs.decodedArea,
                rhs.displayArea
            )
            return lhsRank < rhsRank
        }
    }

    func install(in userContentController: WKUserContentController) {
        userContentController.add(
            self,
            contentWorld: Self.contentWorld,
            name: Self.handlerName
        )
        userContentController.addUserScript(
            WKUserScript(
                source: VideoObserverScript.source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false,
                in: Self.contentWorld
            )
        )
    }

    func clear() {
        frames.removeAll()
        pageURL = nil
        pageTitle = nil
        mediaTitle = nil
    }

    func removeStaleReports(now: Date = Date()) {
        frames = frames.filter {
            now.timeIntervalSince($0.value.receivedAt) < Self.staleInterval
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.handlerName,
              message.world == Self.contentWorld,
              let json = message.body as? String
        else { return }

        receive(json: json, isMainFrame: message.frameInfo.isMainFrame)
    }

    func receive(json: String, now: Date = Date(), isMainFrame: Bool = true) {
        guard json.utf8.count <= 64000,
              let data = json.data(using: .utf8),
              let report = try? JSONDecoder().decode(
                  VideoFrameReport.self,
                  from: data
              ),
              report.frameID.count <= 100,
              report.videos.count <= 50
        else { return }

        if isMainFrame {
            pageURL = report.pageURL
            pageTitle = report.title
            mediaTitle = report.mediaTitle

            if let url = report.linkedURL, let title = report.linkedTitle,
               url.host() == report.pageURL?.host(), title.count <= 500
            {
                linkedTitle = .init(title: title, url: url)
            }
        }

        frames[report.frameID] = FrameVideos(
            videos: report.videos,
            receivedAt: now
        )
        removeStaleReports(now: now)
    }
}
