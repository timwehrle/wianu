<script lang="ts">
	import Button from '#lib/components/Button.svelte';
	import { XIcon } from '@lucide/svelte';
	import { onMount, tick } from 'svelte';
	import { prefersReducedMotion } from 'svelte/motion';
	import { fade } from 'svelte/transition';
	import { afterNavigate } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import {
		cleanReferrer,
		consentCookieValue,
		isAdminPath,
		readConsent,
		settingsEvent,
		trackerUrl,
		websiteId,
		type AnalyticsConsent
	} from '#lib/privacy/analytics.js';

	type Tracker = { track: (payload: Record<string, unknown>) => Promise<void> };
	let ready = $state(false);
	let consent = $state<AnalyticsConsent | null>(null);
	let settingsOpen = $state(false);
	let storageUnavailable = $state(false);
	let tracker: HTMLScriptElement | undefined;
	let lastTrackedPath: string | undefined;
	let rejectedThisVisit = false;
	let settingsTrigger: HTMLElement | null = null;
	let preferences = $state<HTMLElement>();
	let noticeHeight = $state(0);
	let noticeSpace = $state(0);
	let announcement = $state('');
	let initialNoticeAnnounced = false;
	const noticeVisible = $derived(
		ready &&
			(settingsOpen || (consent === null && !isAdminPath(page.url.pathname)))
	);

	function revealFocusedElement(target: HTMLElement) {
		if (
			!preferences ||
			document.activeElement !== target ||
			target === document.body ||
			target === document.documentElement
		) {
			return;
		}
		const panel = preferences.getBoundingClientRect();
		const focused = target.getBoundingClientRect();
		if (preferences.contains(target)) {
			if (
				target !== preferences &&
				(focused.top < panel.top + 8 || focused.bottom > panel.bottom - 8)
			) {
				target.scrollIntoView({
					block: 'nearest',
					inline: 'nearest',
					behavior: 'instant'
				});
			}
			return;
		}
		if (getComputedStyle(preferences).position !== 'fixed') {
			return;
		}
		if (
			focused.right > panel.left &&
			focused.left < panel.right &&
			focused.bottom > panel.top - 12 &&
			focused.top < panel.bottom
		) {
			window.scrollBy({
				top: focused.bottom - panel.top + 12,
				behavior: 'instant'
			});
		}
	}

	function updateNoticeSpace() {
		if (
			!noticeVisible ||
			!preferences ||
			getComputedStyle(preferences).position !== 'fixed'
		) {
			noticeSpace = 0;
		} else {
			const panel = preferences.getBoundingClientRect();
			noticeSpace = Math.ceil(
				panel.height + window.innerHeight - panel.bottom + 12
			);
		}
		document.documentElement.style.setProperty(
			'--privacy-notice-space',
			`${noticeSpace}px`
		);
		const focused = document.activeElement;
		if (focused instanceof HTMLElement) {
			requestAnimationFrame(() => revealFocusedElement(focused));
		}
	}

	$effect(() => {
		if (!ready) {
			return;
		}

		void noticeHeight;
		updateNoticeSpace();
	});

	$effect(() => {
		if (noticeVisible && !settingsOpen && !initialNoticeAnnounced) {
			initialNoticeAnnounced = true;
			announcement =
				'Optional site analytics are off. Choose Allow or Reject in the Site analytics region, or open Privacy settings in the footer.';
		}
	});

	function canTrack(): boolean {
		return (
			!import.meta.env.DEV &&
			consent === 'granted' &&
			!rejectedThisVisit &&
			readConsent(document.cookie) === 'granted' &&
			navigator.doNotTrack !== '1' &&
			navigator.doNotTrack !== 'yes' &&
			!isAdminPath(window.location.pathname)
		);
	}

	function trackPage() {
		if (!canTrack()) {
			return;
		}
		const umami = (window as Window & { umami?: Tracker }).umami;
		const path = window.location.pathname;
		if (!umami || path === lastTrackedPath) {
			return;
		}
		lastTrackedPath = path;
		void umami.track({
			website: websiteId,
			hostname: window.location.hostname,
			url: path,
			title: document.title,
			referrer: cleanReferrer(document.referrer),
			language: navigator.language,
			screen: `${window.screen.width}x${window.screen.height}`
		});
	}

	function startAnalytics() {
		if (!canTrack()) {
			return;
		}
		if (tracker) {
			trackPage();
			return;
		}
		tracker = document.createElement('script');
		tracker.src = trackerUrl;
		tracker.defer = true;
		tracker.dataset.websiteId = websiteId;
		tracker.dataset.autoTrack = 'false';
		tracker.dataset.doNotTrack = 'true';
		tracker.dataset.excludeSearch = 'true';
		tracker.dataset.excludeHash = 'true';
		tracker.onload = trackPage;
		tracker.onerror = () => {
			tracker?.remove();
			tracker = undefined;
		};
		document.head.append(tracker);
	}

	async function closeSettings() {
		const restoreFocus = preferences?.contains(document.activeElement);
		const returnTarget = settingsTrigger?.isConnected
			? settingsTrigger
			: document.getElementById('privacy-settings-trigger');
		settingsOpen = false;
		settingsTrigger = null;
		await tick();
		if (restoreFocus) {
			returnTarget?.focus();
		}
	}

	function choose(choice: AnalyticsConsent) {
		consent = choice;
		rejectedThisVisit = choice === 'denied';
		lastTrackedPath = undefined;
		try {
			document.cookie = consentCookieValue(
				choice,
				window.location.protocol === 'https:'
			);
			storageUnavailable = readConsent(document.cookie) !== choice;
		} catch {
			storageUnavailable = true;
		}
		if (choice === 'granted') {
			startAnalytics();
		}
		announcement = storageUnavailable
			? 'Your choice could not be saved. Analytics is off.'
			: choice === 'granted'
				? 'Site analytics allowed.'
				: 'Site analytics rejected.';
		void closeSettings();
	}

	onMount(() => {
		consent = readConsent(document.cookie);
		ready = true;
		startAnalytics();

		const openSettings = async (event: Event) => {
			const trigger = (event as CustomEvent<{ trigger?: HTMLElement }>).detail
				?.trigger;
			settingsTrigger = trigger?.isConnected
				? trigger
				: document.activeElement instanceof HTMLElement
					? document.activeElement
					: null;
			settingsOpen = true;
			await tick();
			if (preferences) {
				const floating = getComputedStyle(preferences).position === 'fixed';
				preferences.focus({ preventScroll: floating });
				if (!floating) {
					preferences.scrollIntoView({ block: 'start', behavior: 'instant' });
				}
			}
		};

		const handleFocus = (event: FocusEvent) => {
			const target = event.target;
			if (target instanceof HTMLElement) {
				requestAnimationFrame(() => revealFocusedElement(target));
			}
		};

		const handleKeydown = (event: KeyboardEvent) => {
			if (
				event.key === 'Escape' &&
				settingsOpen &&
				consent !== null &&
				event.target instanceof Node &&
				preferences?.contains(event.target)
			) {
				event.stopPropagation();
				void closeSettings();
			}
		};

		window.addEventListener(settingsEvent, openSettings);
		document.addEventListener('focusin', handleFocus);
		document.addEventListener('keydown', handleKeydown);
		window.addEventListener('resize', updateNoticeSpace);

		return () => {
			window.removeEventListener(settingsEvent, openSettings);
			document.removeEventListener('focusin', handleFocus);
			document.removeEventListener('keydown', handleKeydown);
			window.removeEventListener('resize', updateNoticeSpace);
			document.documentElement.style.removeProperty('--privacy-notice-space');
			tracker?.remove();
		};
	});

	afterNavigate(() => {
		if (!ready) {
			return;
		}
		consent = rejectedThisVisit ? 'denied' : readConsent(document.cookie);
		startAnalytics();
	});
</script>

<p
	class="sr-only"
	role="status"
	aria-atomic="true"
>
	{announcement}
</p>

{#if noticeVisible}
	<section
		bind:this={preferences}
		bind:offsetHeight={noticeHeight}
		id="privacy-preferences"
		class="privacy-preferences"
		in:fade={{ duration: prefersReducedMotion.current ? 0 : 220 }}
		aria-labelledby="privacy-title"
		aria-describedby="privacy-description"
		tabindex="-1"
	>
		<div class="notice-heading">
			<h2 id="privacy-title">Site analytics</h2>
			{#if consent !== null && settingsOpen}
				<span class="status"
					>{consent === 'granted' ? 'Allowed' : 'Rejected'}</span
				>
				<Button
					size="icon"
					aria-label="Close privacy settings"
					onclick={closeSettings}
				>
					<XIcon
						size="var(--icon-size)"
						strokeWidth={1}
						aria-hidden="true"
					/>
				</Button>
			{/if}
		</div>
		<p id="privacy-description">
			Optional, cookie-free Umami analytics to understand visits.
			<a href={resolve('privacy-policy#analytics-settings')}>Details</a>
		</p>
		<div class="actions">
			<Button
				type="button"
				onclick={() => choose('denied')}
				aria-label="Reject analytics">Reject</Button
			>
			<Button
				type="button"
				onclick={() => choose('granted')}
				aria-label="Allow analytics">Allow</Button
			>
		</div>
	</section>
{/if}

{#if noticeSpace > 0}
	<div
		class="privacy-space"
		aria-hidden="true"
		style:height={`${noticeSpace}px`}
	></div>
{/if}

{#if storageUnavailable}
	<p class="storage-notice">Choice not saved. Analytics is off.</p>
{/if}

<style lang="scss">
	@use '../../styles/glass';

	.privacy-preferences {
		@include glass.surface(0 16px 48px #0000001f);
		position: fixed;
		right: var(--page-gutter);
		bottom: var(--space-5);
		z-index: 20;
		width: min(26rem, calc(100% - 2 * var(--page-gutter)));
		overflow-y: auto;
		padding: var(--space-6);
		border-radius: var(--space-6);
		background: rgba(255, 255, 255, 0.92);
		max-height: calc(100dvh - var(--page-top));
		scroll-margin-block-start: var(--page-top);
		scroll-padding-block: var(--space-3);
	}

	.privacy-preferences:focus-visible {
		outline: var(--focus-width) solid var(--accent);
		outline-offset: var(--focus-offset);
	}

	.privacy-space {
		flex-shrink: 0;
	}

	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip-path: inset(50%);
		white-space: nowrap;
		border: 0;
	}

	@media (max-height: 480px) {
		.privacy-preferences {
			position: relative;
			right: auto;
			bottom: auto;
			align-self: flex-end;
			margin: var(--space-6) var(--page-gutter) var(--page-top);
			max-height: none;
			overflow: visible;
		}
		.privacy-space {
			display: none;
		}
	}

	.notice-heading {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-3);
		margin-bottom: var(--space-2);
	}

	h2 {
		flex: 1 1 auto;
		font-size: 1.75rem;
		line-height: var(--leading-copy);
	}

	p {
		font-size: var(--text-small);
		line-height: var(--leading-body);
		color: #56544e;
	}

	a {
		color: #1d1d1f;
		text-underline-offset: 0.2em;
		white-space: nowrap;
	}

	.status {
		font-size: var(--text-small);
		color: #56544e;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
		margin-top: var(--space-5);
	}

	.actions :global(.button) {
		flex: 1;
		font-size: var(--text-small);
	}

	.storage-notice {
		position: fixed;
		right: var(--page-gutter);
		bottom: var(--space-1);
		z-index: 21;
		padding: var(--space-2) var(--space-3);
		border-radius: 999px;
		background: var(--background);
		color: var(--foreground);
	}
</style>
