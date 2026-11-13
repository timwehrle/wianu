function createContinueWatchingReader(schedule) {
    const appleItems = new Map();
    const normalizeAppleText = (value) =>
        typeof value === 'string' ? value.replace(/\s+/g, ' ').trim() : '';

    const appleDestination = (value) => {
        try {
            const url = new URL(value, location.href);
            const id = url.pathname.match(/\/(?:movie|episode|show)\/[^/]+\/(umc\.cmc\.[A-Za-z0-9]+)$/)?.[1];

            if (url.origin !== 'https://tv.apple.com' || !id) return null;

            return { id, url: url.href };
        } catch (_) {
            return null;
        }
    };

    const appleQueueItem = (value) => {
        if (!['Episode', 'Movie', 'Show'].includes(value.type)) return null;

        const destination = value.url || value.segue?.url;

        if (typeof destination !== 'string') return null;

        const target = appleDestination(destination);

        if (!target || target.id !== value.id) return null;

        const playable = value.playable || Object.values(value.playables || {})[0];
        const metadata = playable?.canonicalMetadata;
        const isLockup = value.$kind === 'ContinueWatchingLockup';
        const title = normalizeAppleText(
            isLockup
                ? value.title
                : value.showTitle || metadata?.showTitle || metadata?.movieTitle || value.title
        );

        if (!title) return null;

        const episodeTitle = value.type === 'Episode' && !isLockup ? normalizeAppleText(value.title) : '';

        return {
            ...target,
            title: title.slice(0, 500),
            episodeTitle: episodeTitle.slice(0, 500) || null,
            season: value.seasonNumber || metadata?.seasonNumber || null,
            episode: value.episodeNumber || metadata?.episodeNumber || null,
            label: isLockup ? normalizeAppleText(value.ariaLabel) : '',
            prefix: isLockup ? '' : [title, episodeTitle].filter(Boolean).join(', ')
        };
    };

    const captureAppleData = (json) => {
        const pending = [{ value: json, depth: 0 }];
        let visited = 0;

        while (pending.length && visited++ < 20000) {
            const { value, depth } = pending.pop();

            if (!value || typeof value !== 'object' || depth > 20) continue;

            const item = appleQueueItem(value);

            if (item) {
                appleItems.delete(item.id);
                appleItems.set(item.id, item);

                if (appleItems.size > 500) appleItems.delete(appleItems.keys().next().value);
            }

            for (const child of Object.values(value)) {
                if (child && typeof child === 'object') pending.push({ value: child, depth: depth + 1 });
            }
        }

        schedule();
    };

    const readAppleQueue = () => {
        const cards = Array.from(document.querySelectorAll('[data-testid="continue-watching-lockup"]'));

        if (!cards.length) {
            const isHome = /^\/(?:[a-z]{2}(?:-[a-z]{2})?\/?)?$/i.test(location.pathname);
            const signedIn = document.querySelector('[data-testid="account-menu"]');
            const hasRecommendations = document.querySelector('a[data-testid="lockup"][href]');
            const shelf = document.querySelector('[data-testid="continue-watching-lockup-container"]');

            return isHome && signedIn && hasRecommendations && !shelf ? [] : null;
        }

        const entries = [];

        for (const card of cards.slice(0, 100)) {
            const label = normalizeAppleText(
                card.querySelector('.visually-hidden')?.textContent ||
                    card.getAttribute('aria-label') ||
                    card.querySelector('img[alt]')?.alt
            );

            if (!label) return null;

            if (card.matches('a[href]')) {
                const target = appleDestination(card.href);

                if (!target) return null;

                entries.push({ ...target, title: label.slice(0, 500) });
                continue;
            }

            const items = Array.from(appleItems.values());
            const exact = items.filter((item) => item.label === label);
            const matches = exact.length
                ? exact
                : items.filter(
                      (item) => item.prefix && (item.prefix === label || label.startsWith(item.prefix + ', '))
                  );

            if (matches.length !== 1) return null;

            const { label: _, prefix, ...entry } = matches[0];
            entries.push(entry);
        }

        return entries;
    };

    const isAppleDataURL = (value) => {
        try {
            const url = new URL(value, location.href);

            return url.origin === 'https://tv.apple.com' && url.pathname.startsWith('/api/uts/');
        } catch (_) {
            return false;
        }
    };
    const originalAppleFetch = globalThis.fetch;
    globalThis.fetch = async function (...args) {
        const response = await originalAppleFetch.apply(this, args);

        if (response.ok && isAppleDataURL(response.url || args[0]?.url || args[0])) {
            response
                .clone()
                .json()
                .then(captureAppleData)
                .catch(() => {});
        }

        return response;
    };

    const originalAppleSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function (...args) {
        this.addEventListener(
            'load',
            () => {
                if (this.status !== 200 || !isAppleDataURL(this.responseURL)) return;

                try {
                    captureAppleData(
                        this.responseType === 'json' ? this.response : JSON.parse(this.responseText)
                    );
                } catch (_) {}
            },
            { once: true }
        );

        return originalAppleSend.apply(this, args);
    };

    const captureAppleInitialData = () => {
        const script = document.getElementById('serialized-server-data');

        if (!script?.textContent) return false;

        try {
            captureAppleData(JSON.parse(script.textContent));

            return true;
        } catch (_) {
            return false;
        }
    };
    // Apple removes its serialized data during hydration, before DOMContentLoaded.
    const appleDataObserver = new MutationObserver(() => {
        if (captureAppleInitialData()) appleDataObserver.disconnect();
    });

    if (!captureAppleInitialData()) appleDataObserver.observe(document, { childList: true, subtree: true });
    document.addEventListener('DOMContentLoaded', () => appleDataObserver.disconnect(), { once: true });

    return readAppleQueue;
}
