(() => {
    const host = location.hostname;

    if (!(host === 'hbomax.com' || host.endsWith('.hbomax.com'))) return;
    if (globalThis.__wianuContinueWatchingInstalled) return;

    globalThis.__wianuContinueWatchingInstalled = true;

    let previousSnapshot;

    const report = (json) => {
        const alias = json?.data?.attributes?.alias;

        if (typeof alias !== 'string' || !alias.includes('continue-watching')) return;
        if (!Array.isArray(json.included)) return;

        const items = json.data.relationships?.items?.data;

        if (!Array.isArray(items)) return;

        const graph = new Map(json.included.filter(Boolean).map((item) => [`${item.type}:${item.id}`, item]));

        const related = (entity, name) => {
            const value = entity?.relationships?.[name]?.data;
            const ref = Array.isArray(value) ? value[0] : value;

            return ref ? graph.get(`${ref.type}:${ref.id}`) : null;
        };
        const entries = [];

        for (const ref of items.slice(0, 100)) {
            const item = graph.get(`${ref.type}:${ref.id}`);
            const video = related(item, 'video');
            const attributes = video?.attributes;

            if (!attributes || typeof video.id !== 'string') continue;

            const show = related(video, 'show');
            const videoTitle = attributes.name || attributes.originalName;
            const title = show?.attributes?.name || show?.attributes?.originalName || videoTitle;

            if (typeof title !== 'string' || !title.trim()) continue;

            entries.push({
                id: video.id,
                title: title.trim().slice(0, 500),
                episodeTitle: show && typeof videoTitle === 'string' ? videoTitle.slice(0, 500) : null,
                season: Number.isInteger(attributes.seasonNumber) ? attributes.seasonNumber : null,
                episode: Number.isInteger(attributes.episodeNumber) ? attributes.episodeNumber : null
            });
        }

        const snapshot = JSON.stringify(entries);

        if (snapshot === previousSnapshot) return;

        previousSnapshot = snapshot;
        globalThis.webkit?.messageHandlers?.continueWatching_hboMax?.postMessage(snapshot);
    };

    const isCollection = (url) => typeof url === 'string' && url.includes('/cms/collections/');
    const originalFetch = globalThis.fetch;

    globalThis.fetch = async function (...args) {
        const response = await originalFetch.apply(this, args);

        if (response.ok && isCollection(response.url || args[0]?.url || args[0])) {
            response
                .clone()
                .json()
                .then(report)
                .catch(() => {});
        }

        return response;
    };

    const originalSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.send = function (...args) {
        this.addEventListener(
            'load',
            () => {
                if (this.status !== 200 || !isCollection(this.responseURL)) return;

                try {
                    report(this.responseType === 'json' ? this.response : JSON.parse(this.responseText));
                } catch (_) {}
            },
            { once: true }
        );

        return originalSend.apply(this, args);
    };
})();
