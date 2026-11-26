/* exported createContinueWatchingReader */
function createContinueWatchingReader(_schedule, setProfileID) {
	const initialPage = location.href;
	let hydrationRead = false;
	let hydrationEntries = null;
	let navigatedAway = false;
	let profileID;
	let previousEntries;
	let previousHydration;
	let awaitingNewQueue = false;

	const currentProfile = () => {
		try {
			const script = document.querySelector(
				'#dv-web-global-store-data[type="application/json"]'
			);
			const id = JSON.parse(script?.textContent || 'null')?.Profile
				?.currentProfileID;

			return typeof id === 'string' && id.trim() && id.length <= 150
				? id
				: null;
		} catch (_) {
			return null;
		}
	};

	const readHydration = (script) => {
		try {
			const pending = [JSON.parse(script.textContent)];
			const shelves = [];

			while (pending.length) {
				const value = pending.pop();

				if (!value || typeof value !== 'object') {
					continue;
				}

				if (value.isContinueWatching === true) {
					shelves.push(value);
				} else {
					pending.push(...Object.values(value));
				}
			}

			if (shelves.length !== 1) {
				return null;
			}

			const shelf = shelves[0];

			if (
				!Array.isArray(shelf.entities) ||
				shelf.entities.length > 100 ||
				shelf.estimatedTotal !== shelf.entities.length
			) {
				return null;
			}

			const entries = shelf.entities.map((item) => {
				if (
					typeof item.displayTitle !== 'string' ||
					!item.displayTitle.trim() ||
					typeof item.link?.url !== 'string'
				) {
					throw new Error('Incomplete Prime Video entry');
				}

				const url = new URL(item.link.url, document.baseURI);
				const id = url.pathname.match(/\/detail\/([A-Za-z0-9]+)\/?$/)?.[1];

				if (
					url.protocol !== 'https:' ||
					url.hostname !== location.hostname ||
					!id
				) {
					throw new Error('Invalid Prime Video destination');
				}

				const percentage = item.progress?.percentage;

				return {
					id,
					title: item.displayTitle.trim().slice(0, 500),
					url: url.href,
					progress:
						typeof percentage === 'number' &&
						Number.isFinite(percentage) &&
						percentage >= 0 &&
						percentage <= 100
							? percentage / 100
							: null,
					storeOffer: item.entitlementCues?.focusMessage?.icon === 'OFFER_ICON'
				};
			});

			return new Set(entries.map((entry) => entry.id)).size === entries.length
				? entries
				: null;
		} catch (_) {
			return null;
		}
	};

	const hasStoreOffer = (card) =>
		Array.from(
			card?.querySelectorAll('[data-testid="card-overlay"] svg > title') || []
		).some((title) => title.textContent.trim() === 'Store Filled');

	const progressFor = (card) => {
		const bar = card?.querySelector(
			'[data-testid="progress-bar"][aria-valuenow][aria-valuemax]'
		);

		if (!bar) {
			return null;
		}

		const value = Number(bar.getAttribute('aria-valuenow'));
		const maximum = Number(bar.getAttribute('aria-valuemax'));

		return Number.isFinite(value) &&
			Number.isFinite(maximum) &&
			maximum > 0 &&
			value >= 0 &&
			value <= maximum
			? value / maximum
			: null;
	};

	const readEntries = () => {
		if (location.href !== initialPage) {
			navigatedAway = true;
		}

		const script = document.querySelector(
			'#dv-web-page-hydration-data[type="application/json"]'
		);

		if (script) {
			if (navigatedAway) {
				return null;
			}

			if (!hydrationRead) {
				hydrationEntries = readHydration(script);
				hydrationRead = true;
			}

			return hydrationEntries;
		}

		const shelf = document.querySelector(
			'[data-automation-id="continue-watching"], [data-testid="continue-watching"]'
		);

		const cards = Array.from(
			document.querySelectorAll('article[data-card-title]')
		).filter((card) => {
			if (shelf) {
				return shelf.contains(card);
			}

			const progress = card.querySelector(
				'[data-testid="progress-bar"][aria-valuenow]'
			);

			if (!progress) {
				return false;
			}

			const value = Number(progress.getAttribute('aria-valuenow'));
			const maximum = Number(progress.getAttribute('aria-valuemax'));

			return (
				Number.isFinite(value) &&
				Number.isFinite(maximum) &&
				value > 0 &&
				value < maximum
			);
		});

		if (cards.length) {
			return cards.slice(0, 100).map((card) => {
				const anchor = card.querySelector('a[href*="/detail/"]');

				if (!anchor) {
					return {};
				}

				const url = new URL(anchor.href, location.href);

				return {
					id: url.pathname.match(/\/detail\/([A-Za-z0-9]+)/)?.[1],
					title: card.getAttribute('data-card-title')?.trim().slice(0, 500),
					storeOffer: hasStoreOffer(card),
					progress: progressFor(card),
					url: url.href
				};
			});
		}

		if (!shelf) {
			const isHome =
				/^\/(?:region\/[a-z]{2}\/?)?$/i.test(location.pathname) ||
				/^\/gp\/video\/storefront\/?$/i.test(location.pathname);
			const hasRecommendations = document.querySelector(
				'article[data-card-title] a[href*="/detail/"]'
			);

			return isHome && hasRecommendations ? [] : null;
		}

		const anchors = Array.from(shelf.querySelectorAll('a[href*="/detail/"]'));

		if (!anchors.length) {
			return null;
		}

		return anchors.slice(0, 100).map((anchor) => {
			const title =
				anchor.closest('[data-card-title]')?.getAttribute('data-card-title') ||
				anchor.querySelector('img[alt]')?.alt ||
				anchor.getAttribute('aria-label');
			const url = new URL(anchor.href, location.href);

			return {
				id: url.pathname.match(/\/detail\/([A-Za-z0-9]+)/)?.[1],
				title: title?.trim().slice(0, 500),
				storeOffer: hasStoreOffer(anchor.closest('[data-card-title]')),
				progress: progressFor(anchor.closest('[data-card-title]')),
				url: url.href
			};
		});
	};

	const readQueue = () => {
		const current = currentProfile();
		const hydration = document.querySelector(
			'#dv-web-page-hydration-data[type="application/json"]'
		)?.textContent;

		if (current && current !== profileID) {
			if (profileID) {
				awaitingNewQueue = true;
			}

			profileID = current;
			setProfileID(current);
		}

		if (hydrationRead && hydration !== previousHydration) {
			hydrationRead = false;
			hydrationEntries = null;
		}

		const entries = readEntries();
		const signature = entries === null ? null : JSON.stringify(entries);
		const hydrationChanged = hydration !== previousHydration;

		if (
			awaitingNewQueue &&
			(!signature || (signature === previousEntries && !hydrationChanged))
		) {
			return null;
		}

		if (signature !== null) {
			awaitingNewQueue = false;
			previousEntries = signature;
		}

		previousHydration = hydration;

		return entries;
	};

	readQueue.profileID = () => profileID;

	return readQueue;
}
