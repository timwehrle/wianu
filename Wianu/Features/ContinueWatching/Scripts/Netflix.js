function createContinueWatchingReader(schedule) {
    return () => {
        const progressCards = Array.from(document.querySelectorAll('a[data-uia="progress-card"]'));
        const marker = document.querySelector('[data-list-context="continueWatching"]');
        const shelf = marker?.closest('.lolomoRow') || marker;
        const anchors = progressCards.length
            ? progressCards
            : Array.from(shelf?.querySelectorAll('a[href*="/watch/"], a[href*="/title/"]') || []);

        if (!anchors.length) return null;

        return anchors.slice(0, 100).map((anchor) => {
            const tile = anchor.closest('.title-card, .slider-item') || anchor;
            const title =
                anchor.getAttribute('aria-label') ||
                tile.querySelector('.fallback-text')?.textContent ||
                tile.querySelector('img.boxart-image[alt]')?.alt ||
                tile.querySelector('img[alt]')?.alt;
            const url = new URL(anchor.href, location.href);
            const id =
                url.pathname.match(/^\/(?:watch|title)\/(\d+)$/)?.[1] ||
                (url.pathname === '/browse' ? url.searchParams.get('jbv') : null);

            return { id, title: title?.trim().slice(0, 500), url: url.href };
        });
    };
}
