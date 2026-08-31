import Observation
import OSLog
import WebKit

@MainActor
@Observable
final class BrowserSession {
    let router: BrowserNavigationRouter
    let page: WebPage
    let videoDiagnostics: VideoDiagnosticsController

    private(set) var historyRootID: WebPage.BackForwardList.Item.ID?
    private var navigationTask: Task<Void, Never>?
    private var handledNavigationRequestID: UUID?

    init() {
        let router = BrowserNavigationRouter()
        let videoDiagnostics = VideoDiagnosticsController()
        let configuration = WebPage.Configuration()
        videoDiagnostics.install(in: configuration.userContentController)

        let page = WebPage(
            configuration: configuration,
            navigationDecider: BrowserNavigationDecider(router: router)
        )
        page.customUserAgent = Self.customUserAgent

        self.router = router
        self.page = page
        self.videoDiagnostics = videoDiagnostics
    }

    var backItem: WebPage.BackForwardList.Item? {
        guard let historyRootID,
              page.backForwardList.currentItem?.id != historyRootID
        else { return nil }

        return page.backForwardList.backList.last
    }

    var forwardItem: WebPage.BackForwardList.Item? {
        page.backForwardList.forwardList.first
    }

    func startQueuedNavigation() {
        guard let request = router.request,
              request.id != handledNavigationRequestID
        else { return }

        handledNavigationRequestID = request.id
        navigationTask?.cancel()
        navigationTask = Task { await perform(request) }
    }

    func cancelNavigation() {
        navigationTask?.cancel()
    }

    func goBack() {
        guard let backItem else { return }
        router.openHistoryItem(backItem)
    }

    func goForward() {
        guard let forwardItem else { return }
        router.openHistoryItem(forwardItem)
    }

    func reloadOrStop() {
        if page.isLoading {
            page.stopLoading()
        } else {
            router.reload()
        }
    }

    func setPageInteractionBlocked(_ blocked: Bool) async {
        do {
            _ = try await page.callJavaScript(
                Self.pageInteractionScript,
                arguments: ["blocked": blocked],
                contentWorld: .defaultClient
            )
        } catch {
            BrowserNavigationLog.logger.debug(
                "Could not update page interaction: \(String(describing: error), privacy: .private)"
            )
        }
    }
}

private extension BrowserSession {
    static let customUserAgent = """
    Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
    AppleWebKit/605.1.15 (KHTML, like Gecko) \
    Version/26.5.2 Safari/605.1.15
    """

    static let pageInteractionScript = """
    const root = document.documentElement;
    const marker = "data-wianu-interaction-blocked";
    if (blocked) {
        if (!root.hasAttribute(marker)) {
            globalThis.wianuPointerEvents = {
                value: root.style.getPropertyValue("pointer-events"),
                priority: root.style.getPropertyPriority("pointer-events")
            };
            root.setAttribute(marker, "");
        }
        root.style.setProperty("pointer-events", "none", "important");
    } else if (root.hasAttribute(marker)) {
        const previous = globalThis.wianuPointerEvents ?? {
            value: "",
            priority: ""
        };
        root.style.setProperty(
            "pointer-events",
            previous.value,
            previous.priority
        );
        root.removeAttribute(marker);
        delete globalThis.wianuPointerEvents;
    }
    """

    func perform(_ request: BrowserNavigationRouter.Request) async {
        switch request.action {
        case let .load(urlRequest, establishesHistoryRoot):
            BrowserNavigationLog.logger.notice("Executing queued load")
            router.loadDidBegin(request.id)

            if establishesHistoryRoot {
                historyRootID = nil
            }

            let committed = await load(urlRequest)
            router.loadDidEnd(request.id)

            if establishesHistoryRoot {
                router.destinationDidEnd(request.id)
            }

            if committed, establishesHistoryRoot {
                await Task.yield()
                establishHistoryRoot()
            }

        case let .history(item):
            await load(item)

        case .reload:
            await reloadPage()
        }
    }

    func load(_ request: URLRequest) async -> Bool {
        var committed = false

        do {
            for try await event in page.load(request) {
                try Task.checkCancellation()
                if event == .committed {
                    BrowserNavigationLog.logger.notice("Navigation committed")
                    committed = true
                }
            }
            return committed
        } catch where isCancelledNavigation(error) {
            BrowserNavigationLog.logger.debug("Navigation cancelled")
            return false
        } catch {
            BrowserNavigationLog.logger.error(
                "Navigation failed: \(String(describing: error), privacy: .private)"
            )
            return false
        }
    }

    func load(_ item: WebPage.BackForwardList.Item) async {
        do {
            for try await _ in page.load(item) {
                try Task.checkCancellation()
            }
        } catch where isCancelledNavigation(error) {
            BrowserNavigationLog.logger.debug("History navigation cancelled")
        } catch {
            BrowserNavigationLog.logger.error(
                "History navigation failed: \(String(describing: error), privacy: .private)"
            )
        }
    }

    func reloadPage() async {
        do {
            for try await _ in page.reload(fromOrigin: false) {
                try Task.checkCancellation()
            }
        } catch where isCancelledNavigation(error) {
            BrowserNavigationLog.logger.debug("Reload cancelled")
        } catch {
            BrowserNavigationLog.logger.error(
                "Reload failed: \(String(describing: error), privacy: .private)"
            )
        }
    }

    func establishHistoryRoot() {
        guard historyRootID == nil else { return }
        historyRootID = page.backForwardList.currentItem?.id
    }

    func isCancelledNavigation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let navigationError = error as? WebPage.NavigationError,
           case let .failedProvisionalNavigation(underlyingError) = navigationError
        {
            return isCancelledNavigation(underlyingError)
        }

        let error = error as NSError
        return error.domain == NSURLErrorDomain
            && error.code == NSURLErrorCancelled
    }
}
