enum VideoObserverScript {
    static let source = #"""
    (() => {
        if (globalThis.__wianuVideoDiagnosticsInstalled) return;
        globalThis.__wianuVideoDiagnosticsInstalled = true;

        const frameID = globalThis.crypto?.randomUUID?.()
            ?? `${Date.now()}-${Math.random()}`;
        const ids = new WeakMap();
        let nextID = 0;

        const isNetflix = location.hostname === "netflix.com" || location.hostname.endsWith(".netflix.com");

        const finiteNumber = (value, fallback = 0) =>
            Number.isFinite(value) ? value : fallback;

        const videoID = (video) => {
            if (!ids.has(video)) ids.set(video, `${frameID}-${nextID++}`);
            return ids.get(video);
        };

        const sourceInfo = (video) => {
            const source = video.currentSrc || video.src || "";
            let sourceDescription = null;
            if (source.startsWith("blob:")) {
                sourceDescription = "Media Source (blob)";
            } else if (source) {
                try {
                    const url = new URL(source, document.baseURI);
                    sourceDescription = url.host || url.protocol.replace(":", "");
                } catch (_) {}
            }

            let sourceType = null;
            const candidates = Array.from(video.querySelectorAll("source"));
            const selected = candidates.find((candidate) =>
                candidate.src && candidate.src === video.currentSrc
            ) ?? candidates.find((candidate) => candidate.type);
            if (selected?.type) sourceType = selected.type.slice(0, 200);

            return {
                sourceDescription: sourceDescription?.slice(0, 200) ?? null,
                sourceType
            };
        };

        const bufferedAhead = (video) => {
            for (let index = 0; index < video.buffered.length; index++) {
                if (video.buffered.start(index) <= video.currentTime
                    && video.buffered.end(index) >= video.currentTime) {
                    return video.buffered.end(index) - video.currentTime;
                }
            }
            return 0;
        };

        const describe = (video) => {
            const rect = video.getBoundingClientRect();
            const quality = video.getVideoPlaybackQuality?.();
            const droppedFrames = quality?.droppedVideoFrames
                ?? video.webkitDroppedFrameCount;
            const totalFrames = quality?.totalVideoFrames
                ?? video.webkitDecodedFrameCount;

            return {
                id: videoID(video),
                videoWidth: Math.max(0, Math.round(finiteNumber(video.videoWidth))),
                videoHeight: Math.max(0, Math.round(finiteNumber(video.videoHeight))),
                displayWidth: Math.max(0, finiteNumber(rect.width)),
                displayHeight: Math.max(0, finiteNumber(rect.height)),
                paused: video.paused,
                ended: video.ended,
                seeking: video.seeking,
                readyState: video.readyState,
                currentTime: Math.max(0, finiteNumber(video.currentTime)),
                duration: Number.isFinite(video.duration) ? video.duration : null,
                bufferedAhead: Math.max(0, finiteNumber(bufferedAhead(video))),
                droppedFrames: Number.isFinite(droppedFrames)
                    ? Math.max(0, Math.round(droppedFrames)) : null,
                totalFrames: Number.isFinite(totalFrames)
                    ? Math.max(0, Math.round(totalFrames)) : null,
                ...sourceInfo(video)
            };
        };

        const pageTitle = () => {
            // Netflix replaces the document title with its provider name during playback.
            const artwork = isNetflix
                ? document.querySelector(".previewModal--player-titleTreatment-logo, .title-logo")
                : null;
            const playerTitle = isNetflix
                ? document.querySelector('[data-uia="video-title"], .video-title h4, .video-title h3')?.textContent
                : null;

            return (playerTitle?.trim()
                || navigator.mediaSession?.metadata?.title
                || artwork?.alt
                || document.querySelector('meta[property="og:title"]')?.content
                || document.title).slice(0, 500);
        };

        const send = (linkedURL = null, linkedTitle = null) => {
            const json = JSON.stringify({
                frameID,
                pageURL: location.href,
                linkedURL,
                linkedTitle,
                title: pageTitle(),
                videos: Array.from(document.querySelectorAll("video")).map(describe)
            });

            globalThis.webkit?.messageHandlers?.videoDiagnostics?.postMessage(json);
        };

        const capturePlayTitle = (event) => {
            if (!isNetflix) return;
            if (!(event.target instanceof Element)) return;

            const link = event.target.closest('a[href*="/watch/"]');
            if (!link) return;

            const container = link.closest('.previewModal--container, .title-card, .slider-item');
            const artwork = container?.querySelector(
                '.previewModal--player-titleTreatment-logo, .title-logo, img[alt]'
            );
            const title = artwork?.alt || container?.querySelector('.fallback-text')?.textContent;

            if (title?.trim()) send(link.href, title.trim().slice(0, 500));
        };

        document.addEventListener("click", capturePlayTitle, true);

        const events = [
            "durationchange", "emptied", "ended", "loadedmetadata", "pause",
            "play", "playing", "progress", "resize", "seeking", "waiting"
        ];
        for (const event of events) {
            document.addEventListener(event, () => send(), true);
        }

        new MutationObserver(() => send()).observe(document.documentElement, {
            childList: true,
            subtree: true
        });
        setInterval(send, 1000);
        send();
    })();
    """#
}
