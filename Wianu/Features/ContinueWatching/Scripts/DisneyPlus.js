/* exported createContinueWatchingReader */
function createContinueWatchingReader(schedule, setProfileID) {
	const episodePattern = /\bS\s*(\d+)\s*:\s*[EF]\s*(\d+)\b/i;
	const knownSetID = '76aed686-1837-49bd-b4f5-5d2a27c0c8d4';

	let apiEntries = null;
	let apiPage;
	let requestSequence = 0;
	let profileSequence = 0;
	let profileID;
	let awaitingProfileQueue = false;

	const isProfileURL = (value) => {
		try {
			const url = new URL(value, location.href);
			return (
				url.origin === 'https://disney.api.edge.bamgrid.com' &&
				url.pathname === '/v1/public/graphql' &&
				url.searchParams.get('op') === 'me'
			);
		} catch (_) {
			return false;
		}
	};

	const captureProfile = (json, sequence) => {
		const id = json?.data?.me?.account?.activeProfile?.id;
		if (
			sequence !== profileSequence ||
			typeof id !== 'string' ||
			!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(
				id
			)
		) {
			return;
		}
		if (profileID && profileID !== id) {
			apiEntries = null;
			requestSequence++;
			awaitingProfileQueue = true;
		}
		profileID = id;
		setProfileID(id);
		schedule();
	};

	const queueSetID = (value) => {
		try {
			const url = new URL(value, location.href);

			if (url.origin !== 'https://disney.api.edge.bamgrid.com') {
				return null;
			}

			const id = url.pathname.match(
				/^\/explore\/v[0-9]+(?:\.[0-9]+)*\/set\/([A-Za-z0-9._-]{1,150})$/
			)?.[1];
			const style = url.searchParams.get('setStyle');

			if (!id) {
				return null;
			}

			const isContinueWatching = style === 'continue_watching';
			const isKnownSet = style === null && id === knownSetID;

			return isContinueWatching || isKnownSet ? id : null;
		} catch (_) {
			return null;
		}
	};

	const queueItem = (item) => {
		if (item?.type !== 'view' || !Array.isArray(item.actions)) {
			return null;
		}

		const playback = item.actions.find((action) => action?.type === 'playback');
		const id = playback?.deeplinkId;

		if (typeof id !== 'string' || id !== item.id) {
			return null;
		}

		if (!/^[A-Za-z0-9._-]{1,150}$/.test(id)) {
			return null;
		}

		const title = item.visuals?.title;

		if (typeof title !== 'string' || !title.trim()) {
			return null;
		}

		const episodeNumber = (value) => {
			if (value == null) {
				return null;
			}

			if (!/^[0-9]+$/.test(String(value))) {
				return null;
			}

			const number = Number(value);

			return Number.isSafeInteger(number) ? number : null;
		};

		const locale = location.pathname.match(
			/^\/([a-z]{2}(?:-[a-z]{2})?)(?:\/|$)/i
		)?.[1];
		const percentage =
			item.personalization?.userState?.progress?.progressPercentage;

		return {
			id,
			title: title.replace(/\s+/g, ' ').trim().slice(0, 500),
			episodeTitle:
				typeof item.visuals.episodeTitle === 'string'
					? item.visuals.episodeTitle.trim().slice(0, 500) || null
					: null,
			season: episodeNumber(item.visuals.seasonNumber),
			episode: episodeNumber(item.visuals.episodeNumber),
			progress:
				typeof percentage === 'number' &&
				Number.isFinite(percentage) &&
				percentage >= 0 &&
				percentage <= 100
					? percentage / 100
					: null,
			url: new URL(
				`${locale ? '/' + locale : ''}/play/${id}`,
				`https://${location.host}`
			).href
		};
	};

	const beginRequest = (setID) => {
		apiEntries = null;

		return { sequence: ++requestSequence, page: location.href, setID };
	};

	const capture = (json, request) => {
		if (
			request.sequence !== requestSequence ||
			request.page !== location.href
		) {
			return;
		}

		const set = json?.data?.set;

		if (set?.type !== 'set' || set.id !== request.setID) {
			return;
		}

		const pagination = set?.pagination;
		const items = set?.items;

		if (!Array.isArray(items) || items.length > 100) {
			return;
		}

		// Never replace the saved queue with one page of a larger shelf or an unknown response shape.
		if (pagination?.currentOffset !== 0 || pagination.hasPrev !== false) {
			return;
		}

		if (
			pagination.hasMore !== false ||
			pagination.totalCount !== items.length
		) {
			return;
		}

		const entries = items.map(queueItem);

		if (entries.some((entry) => entry === null)) {
			return;
		}

		const uniqueIDs = new Set(entries.map((entry) => entry.id));

		if (uniqueIDs.size !== entries.length) {
			return;
		}

		apiEntries = entries;
		apiPage = request.page;
		awaitingProfileQueue = false;

		schedule();
	};

	const originalFetch = globalThis.fetch;

	globalThis.fetch = function (...args) {
		const url = args[0]?.url ?? args[0];
		const setID = queueSetID(url);
		const request = setID ? beginRequest(setID) : null;
		const profileRequest = isProfileURL(url) ? ++profileSequence : null;
		const pending = originalFetch.apply(this, args);

		if (!request && !profileRequest) {
			return pending;
		}

		return pending.then((response) => {
			if (
				response.ok &&
				(!response.url ||
					(request
						? queueSetID(response.url) === request.setID
						: isProfileURL(response.url)))
			) {
				try {
					response
						.clone()
						.json()
						.then((json) =>
							request
								? capture(json, request)
								: captureProfile(json, profileRequest)
						)
						.catch(() => {});
				} catch (_) {}
			}

			return response;
		});
	};

	// Store the URL during open so we can reject a response from a previous navigation.
	const requestURLs = new WeakMap();
	const originalOpen = XMLHttpRequest.prototype.open;

	XMLHttpRequest.prototype.open = function (...args) {
		requestURLs.set(this, args[1]);

		return originalOpen.apply(this, args);
	};

	const originalSend = XMLHttpRequest.prototype.send;

	XMLHttpRequest.prototype.send = function (...args) {
		const setID = queueSetID(requestURLs.get(this));
		const profileRequest = isProfileURL(requestURLs.get(this))
			? ++profileSequence
			: null;

		if (setID || profileRequest) {
			const request = setID ? beginRequest(setID) : null;

			this.addEventListener(
				'load',
				() => {
					if (
						this.status !== 200 ||
						(request
							? queueSetID(this.responseURL) !== request.setID
							: !isProfileURL(this.responseURL))
					) {
						return;
					}

					try {
						const json =
							this.responseType === 'json'
								? this.response
								: JSON.parse(this.responseText);

						if (request) {
							capture(json, request);
						} else {
							captureProfile(json, profileRequest);
						}
					} catch (_) {}
				},
				{ once: true }
			);
		}

		return originalSend.apply(this, args);
	};

	const readQueue = () => {
		if (awaitingProfileQueue) {
			return null;
		}
		if (apiPage !== location.href) {
			apiEntries = null;
		}

		if (apiEntries !== null && apiPage === location.href) {
			return apiEntries;
		}

		const metadata = Array.from(
			document.querySelectorAll('a[data-testid="cw-set-item-metadata"]')
		);

		if (!metadata.length) {
			const isHome = /^\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?home\/?$/i.test(
				location.pathname
			);
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

			if (!anchor) {
				return {};
			}

			const text = meta.cloneNode(true);
			text
				.querySelectorAll('img,svg,[data-testid*="rating"],[class*="rating"]')
				.forEach((node) => node.remove());

			const lines = Array.from(text.children)
				.map((child) => child.textContent.trim())
				.filter(Boolean);
			const episodeIndex = lines.findIndex((line) => episodePattern.test(line));
			const episodeMetadata =
				episodeIndex >= 0 ? lines[episodeIndex].match(episodePattern) : null;
			const normalize = (value) => value.replace(/\s+/g, ' ').trim();
			const label = normalize(anchor.getAttribute('aria-label') || '');
			const confirmedTitle = lines.find((line) => {
				const candidate = normalize(line);

				return label === candidate || label.startsWith(candidate + ' ');
			});

			const movieMetadataIndex = lines.findIndex((line) =>
				/^\d{4}\s*[•·]/.test(line)
			);
			const titleBoundary =
				episodeIndex >= 0 ? episodeIndex : movieMetadataIndex;

			// Metadata is ordered as remaining time, title, then episode or year/genre.
			// Without a play-label match, a film needs both preceding blocks so a
			// remaining-time label alone cannot be mistaken for its title.
			const metadataTitle =
				titleBoundary > (episodeIndex >= 0 ? 0 : 1)
					? lines[titleBoundary - 1]
					: null;

			const title =
				confirmedTitle ||
				metadataTitle ||
				anchor.querySelector('img[alt]')?.alt;
			const url = new URL(anchor.href, location.href);
			const id =
				anchor.getAttribute('data-item-id') ||
				url.pathname.match(/\/(?:play|video)\/([^/]+)/)?.[1];

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

	readQueue.source = () =>
		apiEntries !== null && apiPage === location.href ? 'response' : 'page';
	readQueue.profileID = () => profileID;

	return readQueue;
}
