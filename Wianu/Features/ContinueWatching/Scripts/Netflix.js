/* exported createContinueWatchingReader */
function createContinueWatchingReader(
	schedule,
	setProfileID,
	publishProfileQueue
) {
	const metadata = new Map();
	let requestSequence = 0;
	let profileSequence = 0;
	let profileID;
	let hasBrowseQueue = false;
	const currentProfile = () => {
		const id =
			globalThis.netflix?.reactContext?.models?.memberContext?.data?.userInfo
				?.userGuid;

		return typeof id === 'string' && id.trim() && id.length <= 150 ? id : null;
	};
	const updateProfile = () => {
		const id = currentProfile();

		if (id && id !== profileID) {
			metadata.clear();
			hasBrowseQueue = false;
			profileID = id;
			profileSequence = requestSequence;
			setProfileID(id);
		}

		return id;
	};
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

	const requestedIDs = (body) => {
		try {
			const request = JSON.parse(body);
			const ids = request?.variables?.unifiedEntityIds;

			if (
				request?.operationName !== 'MiniModalQuery' ||
				!Array.isArray(ids) ||
				ids.length === 0 ||
				ids.length > 100 ||
				!ids.every(
					(id) => typeof id === 'string' && /^Video:\d{1,20}$/.test(id)
				)
			) {
				return null;
			}

			return new Set(ids);
		} catch (_) {
			return null;
		}
	};

	const isBrowseRequest = (body) => {
		try {
			return JSON.parse(body)?.operationName === 'GetBrowsePage';
		} catch (_) {
			return false;
		}
	};

	const browseURL = (value) => {
		try {
			return (
				isGraphQL(value) &&
				new URL(value, location.href).searchParams.get('operationName') ===
					'GetBrowsePage'
			);
		} catch (_) {
			return false;
		}
	};

	const captureBrowse = (json, requestPage, sequence) => {
		const id = json?.data?.currentProfile?.guid;
		const activeProfile = updateProfile();

		if (
			requestPage !== location.href ||
			(activeProfile && id !== activeProfile) ||
			sequence < profileSequence ||
			typeof id !== 'string' ||
			!id ||
			id.length > 150
		) {
			return;
		}

		const sections = json?.data?.page?.sections?.edges;

		if (!Array.isArray(sections)) {
			return;
		}

		const shelves = sections
			.map((edge) => edge?.node)
			.filter((section) =>
				section?.entities?.edges?.some(
					(edge) =>
						edge?.node?.__typename === 'PinotContinueWatchingEntityTreatment'
				)
			);

		if (shelves.length !== 1) {
			return;
		}

		const connection = shelves[0].entities;

		if (!Array.isArray(connection.edges) || connection.edges.length > 100) {
			return;
		}

		const entries = connection.edges.map((edge) => {
			const node = edge?.node;
			const entity = node?.unifiedEntity;
			const videoID = String(entity?.videoId ?? '');
			const title = node?.displayString;

			if (
				node?.__typename !== 'PinotContinueWatchingEntityTreatment' ||
				!/^\d{1,20}$/.test(videoID) ||
				typeof title !== 'string' ||
				!title.trim()
			) {
				return null;
			}

			const playable =
				entity.__typename === 'Show' ? entity.currentEpisode : entity;
			const bookmark = playable?.bookmark?.position;
			const position =
				typeof bookmark === 'number' ? bookmark : bookmark?.parsedValue;
			const runtime = playable?.runtimeSec;

			return {
				id: videoID,
				title: title.trim().slice(0, 500),
				url: 'https://www.netflix.com/title/' + videoID,
				progress:
					Number.isFinite(position) &&
					Number.isFinite(runtime) &&
					runtime > 0 &&
					position >= 0 &&
					position <= runtime
						? position / runtime
						: null,
				episodeMetadataKnown: false
			};
		});

		if (entries.some((entry) => !entry)) {
			return;
		}

		const partial =
			connection.pageInfo?.hasNextPage !== false ||
			!Number.isInteger(connection.totalCount) ||
			connection.totalCount !== entries.length;

		profileSequence = sequence;

		if (id !== profileID) {
			metadata.clear();
		}

		profileID = id;
		hasBrowseQueue = true;
		publishProfileQueue(id, entries, partial);
	};

	const capture = (json, requestPage, request, sequence) => {
		updateProfile();

		if (
			requestPage !== location.href ||
			sequence < profileSequence ||
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

			if (!/^\d{1,20}$/.test(id) || !request.has('Video:' + id)) {
				continue;
			}

			const previous = metadata.get(id) || {};

			if (previous.sequence > sequence) {
				continue;
			}

			const title =
				typeof entity.title === 'string' && entity.title.trim()
					? entity.title.trim().slice(0, 500)
					: previous.title;
			const episodeKnown =
				entity.__typename === 'Movie' ||
				(entity.__typename === 'Show' &&
					Object.hasOwn(entity, 'currentEpisode'));
			const episode =
				entity.__typename === 'Show' ? entity.currentEpisode : null;
			const episodeID = episode?.videoId;
			const changedEpisode =
				episodeKnown &&
				previous.episodeKnown &&
				episodeID !== previous.episodeID;
			const playable = episode || entity;
			const bookmark = playable.bookmark?.position;
			const position =
				typeof bookmark === 'number' ? bookmark : bookmark?.parsedValue;
			const runtime = playable.runtimeSec;
			const progress =
				Number.isFinite(position) &&
				Number.isFinite(runtime) &&
				runtime > 0 &&
				position >= 0 &&
				position <= runtime
					? position / runtime
					: changedEpisode
						? undefined
						: previous.progress;

			const episodeTitle =
				typeof episode?.title === 'string'
					? episode.title.trim().slice(0, 500) || null
					: episodeKnown
						? null
						: previous.episodeTitle;
			const season =
				Number.isSafeInteger(episode?.parentSeason?.number) &&
				episode.parentSeason.number >= 0
					? episode.parentSeason.number
					: episodeKnown
						? null
						: previous.season;
			const episodeNumber =
				Number.isSafeInteger(episode?.number) && episode.number >= 0
					? episode.number
					: episodeKnown
						? null
						: previous.episode;

			metadata.set(id, {
				sequence,
				title,
				progress,
				episodeTitle,
				season,
				episode: episodeNumber,
				episodeKnown: episodeKnown || previous.episodeKnown,
				episodeID: episodeKnown ? episodeID : previous.episodeID
			});
		}

		schedule();
	};

	const originalFetch = globalThis.fetch;

	globalThis.fetch = function (...args) {
		const requestPage = location.href;
		const matches = isGraphQL(args[0]?.url ?? args[0]);
		let body;

		if (matches) {
			try {
				if (args[1]?.body !== undefined) {
					body =
						typeof args[1].body === 'string'
							? Promise.resolve(args[1].body)
							: null;
				} else if (browseURL(args[0]?.url ?? args[0])) {
					body = Promise.resolve('{"operationName":"GetBrowsePage"}');
				} else if (args[0] instanceof Request) {
					body = args[0].clone().text();
				}
			} catch (_) {}
		}

		const sequence = body ? ++requestSequence : null;
		const pending = originalFetch.apply(this, args);

		if (!body) {
			return pending;
		}

		return pending.then(async (response) => {
			if (response.ok && (!response.url || isGraphQL(response.url))) {
				try {
					const requestBody = await body;
					const request = requestedIDs(requestBody);

					if (request || isBrowseRequest(requestBody)) {
						response
							.clone()
							.json()
							.then((json) =>
								request
									? capture(json, requestPage, request, sequence)
									: captureBrowse(json, requestPage, sequence)
							)
							.catch(() => {});
					}
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
		const browse =
			browseURL(requestURLs.get(this)) ||
			(isGraphQL(requestURLs.get(this)) &&
				typeof args[0] === 'string' &&
				isBrowseRequest(args[0]));
		const request =
			isGraphQL(requestURLs.get(this)) && typeof args[0] === 'string'
				? requestedIDs(args[0])
				: null;

		if (request || browse) {
			const requestPage = location.href;
			const sequence = ++requestSequence;

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

						if (request) {
							capture(json, requestPage, request, sequence);
						} else {
							captureBrowse(json, requestPage, sequence);
						}
					} catch (_) {}
				},
				{ once: true }
			);
		}

		return originalSend.apply(this, args);
	};

	const readQueue = () => {
		updateProfile();

		if (hasBrowseQueue) {
			return null;
		}

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
			return null;
		}

		const entries = anchors.slice(0, 100).map((anchor) => {
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
				episodeTitle: metadata.get(id)?.episodeTitle,
				season: metadata.get(id)?.season,
				episode: metadata.get(id)?.episode,
				episodeMetadataKnown: metadata.get(id)?.episodeKnown ?? false,
				url: url.href
			};
		});

		return entries;
	};

	readQueue.partial = () => true;
	readQueue.profileID = currentProfile;

	return readQueue;
}
