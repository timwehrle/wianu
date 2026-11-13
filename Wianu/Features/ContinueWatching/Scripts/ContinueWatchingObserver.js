function observeContinueWatching(configuration, createReader) {
    const host = location.hostname;

    if (!configuration.hosts.some((allowed) => host === allowed || host.endsWith('.' + allowed))) return;

    const marker = '__wianuQueue_' + configuration.id;

    if (globalThis[marker]) return;

    globalThis[marker] = true;
    const messageHandler = globalThis.webkit?.messageHandlers?.['continueWatching_' + configuration.id];
    let previousSnapshot;
    let previousDiagnostics;
    let pending = false;
    let emptyPage;
    let emptyTimer;

    const resetEmptyState = () => {
        clearTimeout(emptyTimer);
        emptyTimer = undefined;
        emptyPage = undefined;
    };

    const appleShelfDiagnostics = (headings) => {
        return headings
            .filter((heading) => heading.matches('h2'))
            .slice(0, 8)
            .map((heading) => {
                const section = heading.closest('[data-testid="section-container"]');

                return {
                    heading: heading.textContent.trim().slice(0, 120),
                    attributes: section
                        ? Array.from(section.attributes)
                              .filter((attribute) =>
                                  /^(id|data-testid|data-automation-id|aria-labelledby)$/.test(attribute.name)
                              )
                              .map((attribute) => [attribute.name, attribute.value.slice(0, 150)])
                        : [],
                    cards: Array.from(section?.querySelectorAll('a[href]') || [])
                        .slice(0, 3)
                        .map((anchor) => ({
                            path: new URL(anchor.href, location.href).pathname,
                            testID: anchor.getAttribute('data-testid'),
                            classes: anchor.className.slice(0, 150),
                            label: anchor.getAttribute('aria-label')?.slice(0, 500),
                            text: anchor.textContent.trim().slice(0, 500),
                            imageLabels: Array.from(anchor.querySelectorAll('img[alt]'))
                                .slice(0, 3)
                                .map((image) => image.alt)
                        }))
                };
            });
    };

    const diagnose = (reason) => {
        const headings = Array.from(document.querySelectorAll('h1,h2,h3,[role="heading"]')).slice(0, 25);
        const details = headings.map((heading) => {
            const containers = [];
            let element = heading;

            for (let depth = 0; element && depth < 6; depth++, element = element.parentElement) {
                containers.push({
                    tag: element.tagName,
                    testID: element.getAttribute('data-testid'),
                    automationID: element.getAttribute('data-automation-id'),
                    classes: typeof element.className === 'string' ? element.className.slice(0, 150) : null
                });
            }

            return { text: heading.textContent.trim().slice(0, 120), containers };
        });
        const samples = Array.from(
            document.querySelectorAll(
                'a[data-testid="cw-set-item-metadata"], a[data-uia="progress-card"], ' +
                    '[data-testid="continue-watching-lockup"], a[data-testid="lockup"]'
            )
        )
            .slice(0, 3)
            .map((anchor) => ({
                testID: anchor.getAttribute('data-testid') || anchor.getAttribute('data-uia'),
                label: anchor.getAttribute('aria-label'),
                blocks: Array.from(anchor.children)
                    .slice(0, 8)
                    .map((child) => child.textContent.trim().slice(0, 150)),
                imageLabels: Array.from(anchor.querySelectorAll('img[alt]'))
                    .slice(0, 5)
                    .map((image) => image.alt)
            }));
        const shelves = configuration.id === 'appleTV' ? appleShelfDiagnostics(headings) : undefined;
        const diagnostics = JSON.stringify(
            {
                provider: configuration.name,
                page: location.hostname + location.pathname,
                reason,
                samples,
                headings: details,
                shelves
            },
            null,
            2
        ).slice(0, 16000);

        if (diagnostics === previousDiagnostics) return;

        previousDiagnostics = diagnostics;
        messageHandler?.postMessage(JSON.stringify({ diagnostics }));
    };

    const scan = () => {
        pending = false;

        try {
            const result = readQueue();

            if (result === null) {
                resetEmptyState();
                diagnose('No readable Continue Watching shelf found');
                return;
            }

            const cards = result.slice(0, 100);
            const entries = cards.filter((entry) => entry.id && entry.title?.trim() && entry.url);

            if (entries.length !== cards.length) {
                resetEmptyState();
                diagnose('Shelf found, but titles or destinations are missing');
                return;
            }

            if (!entries.length) {
                if (document.readyState !== 'complete' || document.querySelector('[aria-busy="true"]')) {
                    resetEmptyState();
                    diagnose('Waiting for the home page to finish loading');
                    return;
                }

                if (emptyPage !== location.href) {
                    resetEmptyState();
                    emptyPage = location.href;
                    emptyTimer = setTimeout(() => {
                        emptyTimer = undefined;
                        scan();
                    }, 2000);
                    diagnose('Waiting to confirm the missing Continue Watching section');
                    return;
                }

                if (emptyTimer !== undefined) return;
            } else {
                resetEmptyState();
            }

            diagnose(entries.length + ' readable titles from ' + result.length + ' cards');
            const snapshot = JSON.stringify(entries);

            if (snapshot === previousSnapshot) return;

            previousSnapshot = snapshot;
            messageHandler?.postMessage(snapshot);
        } catch (_) {}
    };

    const schedule = () => {
        if (emptyTimer !== undefined) resetEmptyState();
        if (pending) return;

        pending = true;
        setTimeout(scan, 500);
    };
    const readQueue = createReader(schedule);

    const start = () => {
        scan();
        new MutationObserver(schedule).observe(document.documentElement, {
            childList: true,
            subtree: true,
            characterData: true,
            attributes: true,
            attributeFilter: [
                'href',
                'aria-label',
                'aria-busy',
                'alt',
                'data-list-context',
                'data-item-id',
                'data-set-style',
                'aria-valuenow',
                'data-card-title'
            ]
        });
        globalThis.addEventListener('load', schedule, { once: true });
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start, { once: true });
    } else {
        start();
    }
}
