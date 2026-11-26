/* exported createContinueWatchingReader */
function createContinueWatchingReader(schedule, setProfileID) {
	let profileID;
	let queue = null;
	const captureProfile = (json) => {
		const id = json?.consumerIdList?.find(
			(item) => item?.namespace === 'APPSTORE_ENGAGEMENT_STATIC'
		)?.consumerId;

		if (
			typeof id !== 'string' ||
			!id.trim() ||
			id.length > 150 ||
			id === profileID
		) {
			return;
		}

		if (profileID) {
			queue = null;
		}

		profileID = id;
		setProfileID(id);
		schedule();
	};
	const isProfileURL = (value) => {
		try {
			const url = new URL(value, location.href);

			return (
				url.origin === 'https://amp-account.tv.apple.com' &&
				url.pathname === '/account/v3/data'
			);
		} catch (_) {
			return false;
		}
	};
	const appleDestination = (value) => {
		try {
			const url = new URL(value, location.href);
			const id = url.pathname.match(
				/\/(?:movie|episode|show)\/[^/]+\/(umc\.cmc\.[A-Za-z0-9]+)$/
			)?.[1];

			return url.origin === 'https://tv.apple.com' && id
				? { id, url: url.href }
				: null;
		} catch (_) {
			return null;
		}
	};

	const captureAppleData = (json) => {
		const pending = [json];
		let visited = 0;

		while (pending.length && visited++ < 20000) {
			const value = pending.pop();

			if (!value || typeof value !== 'object') {
				continue;
			}

			if (
				typeof value.id === 'string' &&
				/^(?:uts\.col\.)?(?:ChannelUpNext|upnext)/i.test(value.id) &&
				Array.isArray(value.items)
			) {
				const entries = [];

				for (const item of value.items) {
					if (item?.$kind !== 'ContinueWatchingLockup') {
						return;
					}

					const target = appleDestination(
						item.segue?.url || item.contextAction?.url
					);
					const playable =
						item.playAction?.contentDescriptor?.items?.[0]?.playable;
					const metadata = playable?.canonicalMetadata;

					if (
						!target ||
						target.id !== item.id ||
						typeof item.title !== 'string' ||
						!item.title.trim()
					) {
						return;
					}

					const progress = item.progress;

					entries.push({
						...target,
						title: item.title.trim().slice(0, 500),
						episodeTitle:
							item.type === 'Episode' &&
							typeof metadata?.episodeTitle === 'string'
								? metadata.episodeTitle.slice(0, 500)
								: null,
						season: Number.isInteger(metadata?.seasonNumber)
							? metadata.seasonNumber
							: null,
						episode: Number.isInteger(metadata?.episodeNumber)
							? metadata.episodeNumber
							: null,
						progress:
							typeof progress === 'number' &&
							Number.isFinite(progress) &&
							progress >= 0 &&
							progress <= 100
								? progress / 100
								: null
					});
				}

				queue = entries.slice(0, 100);
				schedule();

				return;
			}

			for (const child of Object.values(value)) {
				if (child && typeof child === 'object') {
					pending.push(child);
				}
			}
		}
	};

	const readAppleQueue = () => queue;

	const isAppleDataURL = (value) => {
		try {
			const url = new URL(value, location.href);

			return (
				url.origin === 'https://tv.apple.com' &&
				url.pathname.startsWith('/api/uts/')
			);
		} catch (_) {
			return false;
		}
	};
	const originalAppleFetch = globalThis.fetch;

	globalThis.fetch = async function (...args) {
		const response = await originalAppleFetch.apply(this, args);
		const url = response.url || args[0]?.url || args[0];

		if (response.ok && isProfileURL(url)) {
			response
				.clone()
				.json()
				.then(captureProfile)
				.catch(() => {});
		}

		if (response.ok && isAppleDataURL(url)) {
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
				if (
					this.status !== 200 ||
					(!isAppleDataURL(this.responseURL) && !isProfileURL(this.responseURL))
				) {
					return;
				}

				try {
					const json =
						this.responseType === 'json'
							? this.response
							: JSON.parse(this.responseText);

					if (isProfileURL(this.responseURL)) {
						captureProfile(json);
					} else {
						captureAppleData(json);
					}
				} catch (_) {}
			},
			{ once: true }
		);

		return originalAppleSend.apply(this, args);
	};

	const captureAppleInitialData = () => {
		const script = document.getElementById('serialized-server-data');

		if (!script?.textContent) {
			return false;
		}

		try {
			captureAppleData(JSON.parse(script.textContent));

			return true;
		} catch (_) {
			return false;
		}
	};
	// Apple removes its serialized data during hydration, before DOMContentLoaded.
	const appleDataObserver = new MutationObserver(() => {
		if (captureAppleInitialData()) {
			appleDataObserver.disconnect();
		}
	});

	if (!captureAppleInitialData()) {
		appleDataObserver.observe(document, { childList: true, subtree: true });
	}

	document.addEventListener(
		'DOMContentLoaded',
		() => appleDataObserver.disconnect(),
		{ once: true }
	);

	readAppleQueue.profileID = () => profileID;

	return readAppleQueue;
}
