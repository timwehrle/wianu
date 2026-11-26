(() => {
	const host = location.hostname;

	if (!(host === 'hbomax.com' || host.endsWith('.hbomax.com'))) {
		return;
	}

	if (globalThis.__wianuContinueWatchingInstalled) {
		return;
	}

	globalThis.__wianuContinueWatchingInstalled = true;

	let previousSnapshot;
	let profileID;
	let profileRequest = 0;
	let profilePending = false;
	const handler = globalThis.webkit?.messageHandlers?.continueWatching_hboMax;

	const requestKind = (value) => {
		try {
			const url = new URL(value, location.href);

			if (
				url.protocol !== 'https:' ||
				!(
					url.hostname === 'hbo.com' ||
					url.hostname.endsWith('.hbo.com') ||
					url.hostname === 'hbomax.com' ||
					url.hostname.endsWith('.hbomax.com')
				)
			) {
				return null;
			}

			if (url.pathname === '/users/me') {
				return 'profile';
			}

			if (url.pathname.includes('/cms/collections/')) {
				return 'collection';
			}
		} catch (_) {}

		return null;
	};

	const reportProfile = (json, request) => {
		const id = json?.data?.attributes?.selectedProfileId;

		if (request !== profileRequest) {
			return;
		}

		profilePending = false;

		if (
			typeof id !== 'string' ||
			!id.trim() ||
			id.length > 150 ||
			id === profileID
		) {
			return;
		}

		profileID = id;
		previousSnapshot = undefined;
		handler?.postMessage(JSON.stringify({ profileID: id }));
	};

	const report = (json, requestProfile) => {
		if (profilePending || requestProfile !== profileID) {
			return;
		}

		const alias = json?.data?.attributes?.alias;

		if (typeof alias !== 'string' || !alias.includes('continue-watching')) {
			return;
		}

		const items = json.data.relationships?.items?.data;

		if (!Array.isArray(items)) {
			return;
		}

		if (items.length && !Array.isArray(json.included)) {
			return;
		}

		const graph = new Map(
			(json.included || [])
				.filter(Boolean)
				.map((item) => [`${item.type}:${item.id}`, item])
		);

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

			if (!attributes || typeof video.id !== 'string') {
				return;
			}

			const show = related(video, 'show');
			const duration = related(video, 'edit')?.attributes?.duration;
			const position = attributes.viewingHistory?.position;
			const videoTitle = attributes.name || attributes.originalName;
			const title =
				show?.attributes?.name || show?.attributes?.originalName || videoTitle;

			if (typeof title !== 'string' || !title.trim()) {
				return;
			}

			entries.push({
				id: video.id,
				title: title.trim().slice(0, 500),
				episodeTitle:
					show && typeof videoTitle === 'string'
						? videoTitle.slice(0, 500)
						: null,
				season: Number.isInteger(attributes.seasonNumber)
					? attributes.seasonNumber
					: null,
				episode: Number.isInteger(attributes.episodeNumber)
					? attributes.episodeNumber
					: null,
				progress:
					typeof position === 'number' &&
					Number.isFinite(position) &&
					typeof duration === 'number' &&
					Number.isFinite(duration) &&
					duration > 0 &&
					position >= 0 &&
					position <= duration
						? position / duration
						: null
			});
		}

		const snapshot = JSON.stringify(
			profileID ? { profileID, entries, partial: false } : entries
		);

		if (snapshot === previousSnapshot) {
			return;
		}

		previousSnapshot = snapshot;
		handler?.postMessage(snapshot);
	};

	const originalFetch = globalThis.fetch;

	globalThis.fetch = async function (...args) {
		const kind = requestKind(args[0]?.url || args[0]);
		const request = kind === 'profile' ? ++profileRequest : profileID;

		if (kind === 'profile') {
			profilePending = true;
		}

		let response;

		try {
			response = await originalFetch.apply(this, args);
		} catch (error) {
			if (kind === 'profile' && request === profileRequest) {
				profilePending = false;
			}

			throw error;
		}

		if (
			response.ok &&
			kind &&
			(!response.url || requestKind(response.url) === kind)
		) {
			response
				.clone()
				.json()
				.then((json) =>
					kind === 'profile'
						? reportProfile(json, request)
						: report(json, request)
				)
				.catch(() => {
					if (kind === 'profile' && request === profileRequest) {
						profilePending = false;
					}
				});
		} else if (kind === 'profile' && request === profileRequest) {
			profilePending = false;
		}

		return response;
	};

	const originalSend = XMLHttpRequest.prototype.send;
	const originalOpen = XMLHttpRequest.prototype.open;

	XMLHttpRequest.prototype.open = function (method, url, ...args) {
		this.__wianuRequestKind = requestKind(url);

		return originalOpen.call(this, method, url, ...args);
	};

	XMLHttpRequest.prototype.send = function (...args) {
		const kind = this.__wianuRequestKind;
		const request = kind === 'profile' ? ++profileRequest : profileID;

		if (kind === 'profile') {
			profilePending = true;
		}

		this.addEventListener(
			'loadend',
			() => {
				if (kind === 'profile' && request === profileRequest) {
					profilePending = false;
				}
			},
			{ once: true }
		);
		this.addEventListener(
			'load',
			() => {
				if (
					this.status !== 200 ||
					!kind ||
					requestKind(this.responseURL) !== kind
				) {
					return;
				}

				try {
					const json =
						this.responseType === 'json'
							? this.response
							: JSON.parse(this.responseText);

					if (kind === 'profile') {
						reportProfile(json, request);
					} else {
						report(json, request);
					}
				} catch (_) {}
			},
			{ once: true }
		);

		return originalSend.apply(this, args);
	};
})();
