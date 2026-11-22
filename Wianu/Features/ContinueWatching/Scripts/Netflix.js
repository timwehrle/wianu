/* exported createContinueWatchingReader */
function createContinueWatchingReader(schedule) {
	const metadata = new Map();
	const pageKey = () => {
		const url = new URL(location.href);

		if (/^\/browse\/?$/.test(url.pathname)) {
			url.searchParams.delete('jbv');
		}

		return url.href;
	};
	let page = pageKey();

	const isGraphQL = (value) => {
		try {
			const url = new URL(value, location.href);

			return (
				url.origin === 'https://www.netflix.com' && url.pathname === '/graphql'
			);
		} catch (_) {
			return false;
		}
	};

	const capture = (json, requestPage) => {
		if (
			requestPage !== location.href ||
			!Array.isArray(json?.data?.unifiedEntities)
		) {
			return;
		}

		if (page !== pageKey()) {
			metadata.clear();
			page = pageKey();
		}

		for (const entity of json.data.unifiedEntities.slice(0, 100)) {
			const id = String(entity?.videoId ?? '');

			if (!/^\d{1,20}$/.test(id)) {
				continue;
			}

			const previous = metadata.get(id) || {};
			const title =
				typeof entity.title === 'string' && entity.title.trim()
					? entity.title.trim().slice(0, 500)
					: previous.title;
			const position = entity.bookmark?.position;
			const runtime = entity.runtimeSec;
			const progress =
				Number.isFinite(position) &&
				Number.isFinite(runtime) &&
				runtime > 0 &&
				position >= 0 &&
				position <= runtime
					? position / runtime
					: previous.progress;

			metadata.set(id, { title, progress });
		}

		schedule();
	};

	const originalFetch = globalThis.fetch;

	globalThis.fetch = function (...args) {
		const requestPage = location.href;
		const matches = isGraphQL(args[0]?.url ?? args[0]);
		const pending = originalFetch.apply(this, args);

		if (!matches) {
			return pending;
		}

		return pending.then((response) => {
			if (response.ok && (!response.url || isGraphQL(response.url))) {
				try {
					response
						.clone()
						.json()
						.then((json) => capture(json, requestPage))
						.catch(() => {});
				} catch (_) {}
			}

			return response;
		});
	};

	const requestURLs = new WeakMap();
	const originalOpen = XMLHttpRequest.prototype.open;

	XMLHttpRequest.prototype.open = function (...args) {
		requestURLs.set(this, args[1]);

		return originalOpen.apply(this, args);
	};

	const originalSend = XMLHttpRequest.prototype.send;

	XMLHttpRequest.prototype.send = function (...args) {
		if (isGraphQL(requestURLs.get(this))) {
			const requestPage = location.href;

			this.addEventListener(
				'load',
				() => {
					if (this.status !== 200 || !isGraphQL(this.responseURL)) {
						return;
					}

					try {
						const json =
							this.responseType === 'json'
								? this.response
								: JSON.parse(this.responseText);

						capture(json, requestPage);
					} catch (_) {}
				},
				{ once: true }
			);
		}

		return originalSend.apply(this, args);
	};

	return () => {
		if (page !== pageKey()) {
			metadata.clear();
			page = pageKey();
		}
		const progressCards = Array.from(
			document.querySelectorAll('a[data-uia="progress-card"]')
		);
		const marker = document.querySelector(
			'[data-list-context="continueWatching"]'
		);
		const shelf = marker?.closest('.lolomoRow') || marker;
		const anchors = progressCards.length
			? progressCards
			: Array.from(
					shelf?.querySelectorAll('a[href*="/watch/"], a[href*="/title/"]') ||
						[]
				);

		if (!anchors.length) {
			const isHome =
				/^\/browse\/?$/.test(location.pathname) &&
				!new URL(location.href).searchParams.has('jbv');
			const hasRecommendations = document.querySelector(
				'a[href*="/title/"], a[href*="/browse?jbv="]'
			);

			return isHome && hasRecommendations && !shelf ? [] : null;
		}

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

			return {
				id,
				title: metadata.get(id)?.title || title?.trim().slice(0, 500),
				progress: metadata.get(id)?.progress,
				url: url.href
			};
		});
	};
}
