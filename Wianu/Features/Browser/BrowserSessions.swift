import Observation
import WebKit

@MainActor
@Observable
final class BrowserSessions {
    private struct Entry {
        let siteID: SavedSite.ID?
        let siteURL: URL?
        let session: BrowserSession
    }

    private let continueWatchingQueues: [ContinueWatchingController]
    private var entries: [Entry] = []
    private(set) var active: BrowserSession?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    init(continueWatchingQueues: [ContinueWatchingController]) {
        self.continueWatchingQueues = continueWatchingQueues
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.discardInactive() }
        }
        
        source.resume()
        memoryPressureSource = source
    }

    func open(_ request: AppModel.NavigationRequest) {
        let site = request.site
        let existingIndex = entries.firstIndex { entry in
            guard let site else { return false }
            return entry.siteID == site.id && entry.siteURL == site.url
        }
        
        let entry: Entry
        let isExisting = existingIndex != nil

        if let existingIndex {
            entry = entries.remove(at: existingIndex)
        } else {
            let session = BrowserSession(continueWatchingQueues: continueWatchingQueues)
            entry = Entry(siteID: site?.id, siteURL: site?.url, session: session)
        }

        if active !== entry.session {
         active?.pausePlayback()
        }
        
        entry.session.cancelPendingPause()
        active = entry.session
        entries.append(entry)
        
        while entries.count > 3 {
            entries.removeFirst().session.cancelNavigation()
        }

        if !isExisting || request.intent == .navigate {
            entry.session.router.openDestination(request.url)
        }
    }

    func pauseActive() {
        active?.pausePlayback()
    }

    func cancelNavigation() {
        for entry in entries {
            entry.session.cancelNavigation()
        }
    }

    func removeChangedSites(_ sites: [SavedSite]) {
        let activeWasRemoved = entries.contains { entry in
            entry.session === active && entry.siteID != nil
                && !sites.contains { $0.id == entry.siteID && $0.url == entry.siteURL }
        }
       
        entries.removeAll { entry in
            guard let siteID = entry.siteID,
                  !sites.contains(where: { $0.id == siteID && $0.url == entry.siteURL }) else { return false }
            entry.session.cancelNavigation()
            return true
        }
        
        if activeWasRemoved {
            active?.pausePlayback()
            active = nil
        }
    }

    private func discardInactive() {
        entries.removeAll { entry in
            guard entry.session !== active else { return false }
            entry.session.cancelNavigation()
            return true
        }
    }
}
