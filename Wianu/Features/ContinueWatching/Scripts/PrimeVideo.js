function createContinueWatchingReader(schedule) {
    return () => {
        const cards = Array.from(document.querySelectorAll('article[data-card-title]')).filter((card) => {
            const progress = card.querySelector('[data-testid="progress-bar"][aria-valuenow]');

            if (!progress) return false;

            const value = Number(progress.getAttribute('aria-valuenow'));
            const maximum = Number(progress.getAttribute('aria-valuemax'));

            return Number.isFinite(value) && Number.isFinite(maximum) && value > 0 && value < maximum;
        });

        if (cards.length) {
            return cards.slice(0, 100).map((card) => {
                const anchor = card.querySelector('a[href*="/detail/"]');

                if (!anchor) return {};

                const url = new URL(anchor.href, location.href);

                return {
                    id: url.pathname.match(/\/detail\/([A-Za-z0-9]+)/)?.[1],
                    title: card.getAttribute('data-card-title')?.trim().slice(0, 500),
                    url: url.href
                };
            });
        }

        const shelf = document.querySelector(
            '[data-automation-id="continue-watching"], [data-testid="continue-watching"]'
        );

        if (!shelf) {
            const isHome =
                /^\/(?:region\/[a-z]{2}\/?)?$/i.test(location.pathname) ||
                /^\/gp\/video\/storefront\/?$/i.test(location.pathname);
            const hasRecommendations = document.querySelector('article[data-card-title] a[href*="/detail/"]');

            return isHome && hasRecommendations ? [] : null;
        }

        const anchors = Array.from(shelf.querySelectorAll('a[href*="/detail/"]'));

        if (!anchors.length) return null;

        return anchors.slice(0, 100).map((anchor) => {
            const title =
                anchor.closest('[data-card-title]')?.getAttribute('data-card-title') ||
                anchor.querySelector('img[alt]')?.alt ||
                anchor.getAttribute('aria-label');
            const url = new URL(anchor.href, location.href);

            return {
                id: url.pathname.match(/\/detail\/([A-Za-z0-9]+)/)?.[1],
                title: title?.trim().slice(0, 500),
                url: url.href
            };
        });
    };
}
