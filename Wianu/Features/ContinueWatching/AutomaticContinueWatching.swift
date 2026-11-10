import Foundation

struct AutomaticContinueWatching {
    private struct Sample {
        let key: String
        let videoID: String
        let position: Double
        let date: Date
    }

    private static let requiredPlaybackSeconds: TimeInterval = 30
    private static let minimumVideoDuration: TimeInterval = 300

    private var titles: [String: PlaybackPageTitle] = [:]
    private var previous: Sample?
    private var watchedSeconds: TimeInterval = 0
    private var savedKey: String?

    mutating func observe(
        url: URL,
        title: String?,
        siteName: String,
        video: VideoDiagnostic?,
        now: Date = .now
    ) -> PlaybackPageTitle? {
        let key = URLNormalizer.continueWatchingComparisonKey(for: url)

        rememberTitle(title, for: url, siteName: siteName)

        defer {
            previous = video.map { Sample(key: key, videoID: $0.id, position: $0.currentTime, date: now) }
        }

        guard let video, video.isPlaying, !video.seeking, video.readyState >= 3,
              video.displayArea > 0, let duration = video.duration, duration >= Self.minimumVideoDuration
        else {
            watchedSeconds = 0
            return nil
        }

        guard let previous, previous.key == key, previous.videoID == video.id else {
            watchedSeconds = 0
            savedKey = nil
            return nil
        }

        let elapsed = now.timeIntervalSince(previous.date)
        let advance = video.currentTime - previous.position

        guard elapsed > 0, elapsed <= 3, advance > 0, advance <= elapsed * 2.5 else {
            watchedSeconds = 0
            return nil
        }

        watchedSeconds += min(elapsed, advance)

        guard watchedSeconds >= Self.requiredPlaybackSeconds, savedKey != key,
              let candidate = titles[key] else { return nil }

        savedKey = key

        return candidate
    }

    mutating func rememberTitle(_ title: String?, for url: URL, siteName: String) {
        guard let title = usefulTitle(title, siteName: siteName, url: url) else { return }

        let key = URLNormalizer.continueWatchingComparisonKey(for: url)

        if titles.count >= 100, titles[key] == nil {
            titles.removeAll()
        }

        titles[key] = PlaybackPageTitle(title: title, url: URLNormalizer.continueWatchingPageURL(for: url))
    }

    private func usefulTitle(_ title: String?, siteName: String, url: URL) -> String? {
        guard let title else { return nil }

        let cleaned = PageTitleCleaner.clean(title, siteName: siteName)

        let generic = [siteName, url.host() ?? ""]

        guard !cleaned.isEmpty,
              !generic.contains(where: { cleaned.caseInsensitiveCompare($0) == .orderedSame })
        else { return nil }

        return cleaned
    }
}
