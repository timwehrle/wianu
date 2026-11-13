function createContinueWatchingReader(schedule) {
    const episodePattern = /\bS\s*(\d+)\s*:\s*[EF]\s*(\d+)\b/i;

    return () => {
        const metadata = Array.from(document.querySelectorAll('a[data-testid="cw-set-item-metadata"]'));

        if (!metadata.length) {
            const isHome = /^\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?home\/?$/i.test(location.pathname);
            const hasRecommendations = document.querySelector(
                'a[data-testid="set-item"][data-item-id][href]'
            );
            const shelf = document.querySelector(
                '[data-set-style="continue_watching"], [data-testid="cw-set-item-wrapper"]'
            );

            return isHome && hasRecommendations && !shelf ? [] : null;
        }

        return metadata.slice(0, 100).map((meta) => {
            let tile = meta.parentElement;

            for (
                let depth = 0;
                depth < 5 && tile && !tile.querySelector('a[data-testid="set-item"]');
                depth++
            ) {
                tile = tile.parentElement;
            }
            const anchor = tile?.querySelector('a[data-testid="set-item"]');

            if (!anchor) return {};

            const text = meta.cloneNode(true);
            text.querySelectorAll('img,svg,[data-testid*="rating"],[class*="rating"]').forEach((node) =>
                node.remove()
            );
            const lines = Array.from(text.children)
                .map((child) => child.textContent.trim())
                .filter(Boolean);
            const episodeIndex = lines.findIndex((line) => episodePattern.test(line));
            const episodeMetadata = episodeIndex >= 0 ? lines[episodeIndex].match(episodePattern) : null;
            const normalize = (value) => value.replace(/\s+/g, ' ').trim();
            const label = normalize(anchor.getAttribute('aria-label') || '');
            const confirmedTitle = lines.find((line) => {
                const candidate = normalize(line);

                return label === candidate || label.startsWith(candidate + ' ');
            });
            const candidates = episodeIndex > 0 ? lines.slice(0, episodeIndex).reverse() : [];
            const title =
                confirmedTitle ||
                candidates.find(
                    (line) =>
                        /\p{L}/u.test(line) &&
                        !/^\d{4}\s*[•·]/.test(line) &&
                        !/^\d+\s*(?:h|min|m|std|sek)(?:\b|\.)/i.test(line)
                ) ||
                anchor.querySelector('img[alt]')?.alt;
            const url = new URL(anchor.href, location.href);
            const id =
                anchor.getAttribute('data-item-id') || url.pathname.match(/\/(?:play|video)\/([^/]+)/)?.[1];

            return {
                id,
                title: title?.slice(0, 500),
                episodeTitle: episodeIndex >= 0 ? lines[episodeIndex] : null,
                season: episodeMetadata ? Number(episodeMetadata[1]) : null,
                episode: episodeMetadata ? Number(episodeMetadata[2]) : null,
                url: url.href
            };
        });
    };
}
