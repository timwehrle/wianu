<script lang="ts">
	import Button from '#lib/components/Button.svelte';
	import { resolve } from '$app/paths';
	import { prefersReducedMotion } from 'svelte/motion';
	import { fade, slide } from 'svelte/transition';
	import { ArrowDownIcon, ArrowRightIcon } from '@lucide/svelte';

	let isOpen = $state(false);
	let menuTrigger = $state<HTMLButtonElement>();
	let menu = $state<HTMLElement>();

	function toggleMenu() {
		isOpen = !isOpen;
	}

	function closeMenu() {
		if (isOpen) {
			toggleMenu();
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape' && isOpen) {
			closeMenu();
			menuTrigger?.focus();
		}
	}

	function handlePointerdown(event: PointerEvent) {
		if (
			isOpen &&
			!menuTrigger?.contains(event.target as Node) &&
			!menu?.contains(event.target as Node)
		) {
			closeMenu();
		}
	}

	function handleResize() {
		if (
			isOpen &&
			menuTrigger &&
			getComputedStyle(menuTrigger).display === 'none'
		) {
			closeMenu();
		}
	}
</script>

<svelte:window
	onkeydown={handleKeydown}
	onpointerdown={handlePointerdown}
	onresize={handleResize}
/>

{#if isOpen}
	<div
		class="nav-backdrop"
		aria-hidden="true"
		transition:fade={{ duration: prefersReducedMotion.current ? 0 : 200 }}
	></div>
{/if}

<header>
	<div class="nav-shell">
		<div class="nav-bar">
			<div class="nav-main">
				<div class="nav-logo">
					<a
						href={resolve('')}
						onclick={closeMenu}>Wianu</a
					>
				</div>
				<a
					class="nav-weekly-link"
					href={resolve('weekly')}
					onclick={closeMenu}>Weekly</a
				>
			</div>
			<nav
				class="nav-desktop"
				aria-label="Site navigation"
			>
				<a href={resolve('the-app')}>The App</a>
				<a href={resolve('weekly')}>Weekly</a>
				<a
					class="nav-desktop-download"
					href={resolve('download')}
					data-sveltekit-reload
					target="_blank"
					rel="noopener noreferrer"
				>
					Download
					<ArrowDownIcon
						size="var(--icon-size)"
						strokeWidth={1.0}
						aria-hidden="true"
					/>
				</a>
			</nav>
			<Button
				bind:element={menuTrigger}
				class="nav-menu-toggle"
				type="button"
				aria-label={isOpen ? 'Close menu' : 'Open menu'}
				aria-expanded={isOpen}
				aria-controls="site-menu"
				onclick={toggleMenu}
			>
				<span>{isOpen ? 'Close' : 'Menu'}</span>
			</Button>
		</div>
		{#if isOpen}
			<nav
				bind:this={menu}
				id="site-menu"
				class="nav-menu"
				aria-label="Site navigation"
				transition:slide={{ duration: prefersReducedMotion.current ? 0 : 200 }}
			>
				<ul class="nav-menu-list">
					<li>
						<a
							class="nav-menu-link"
							href={resolve('the-app')}
							onclick={closeMenu}
						>
							<span class="nav-menu-copy">
								<span class="nav-menu-title">The App</span>
								<span class="nav-menu-description"
									>Meet your streaming home</span
								>
							</span>
							<span
								class="nav-menu-arrow"
								aria-hidden="true"
							>
								<ArrowRightIcon
									size="var(--icon-size)"
									strokeWidth={1.0}
								/>
							</span>
						</a>
					</li>
					<li>
						<a
							class="nav-menu-download"
							href={resolve('download')}
							data-sveltekit-reload
							onclick={closeMenu}
							target="_blank"
							rel="noopener noreferrer"
						>
							<span class="nav-menu-copy">
								<span class="nav-menu-title">Download Wianu</span>
								<span class="nav-menu-description">For macOS 26 or later</span>
							</span>
							<span
								class="nav-menu-arrow"
								aria-hidden="true"
							>
								<ArrowDownIcon
									size="var(--icon-size)"
									strokeWidth={1.0}
									aria-hidden="true"
								/>
							</span>
						</a>
					</li>
				</ul>
			</nav>
		{/if}
	</div>
</header>

<style lang="scss">
	@use '../../styles/glass';

	.nav-backdrop {
		position: fixed;
		inset: 0;
		z-index: 9;
		-webkit-backdrop-filter: blur(3px);
		backdrop-filter: blur(3px);
		background: rgb(0 0 0 / 20%);
	}

	header {
		position: fixed;
		width: 100%;
		z-index: 10;
	}

	.nav-shell {
		width: calc(100% - 2 * var(--page-gutter));
		max-width: var(--content-width);
		margin: var(--space-4) auto;
		color: #1d1d1f;
	}

	.nav-bar {
		display: flex;
		gap: var(--space-2);
	}

	.nav-main,
	.nav-desktop a {
		@include glass.surface;
		border-radius: 999px;
	}

	.nav-main {
		padding: var(--space-3) var(--space-5);
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-4);
		flex: 1;
		min-width: 0;
		min-height: 3.5rem;
	}

	.nav-menu {
		margin-top: var(--space-3);
	}

	@media (max-height: 480px) {
		.nav-menu {
			max-height: calc(100dvh - 6.5rem);
			overflow-y: auto;
			overscroll-behavior: contain;
		}
	}

	.nav-menu-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		list-style: none;
	}

	.nav-menu-link,
	.nav-menu-download {
		@include glass.surface;
		display: flex;
		align-items: center;
		gap: var(--space-4);
		width: 100%;
		padding: var(--space-4);
		border-radius: var(--space-4);
		color: inherit;
		text-decoration: none;
	}

	.nav-main,
	.nav-desktop a,
	.nav-menu-link,
	.nav-menu-download {
		transition: background-color 150ms;
	}

	.nav-main:has(a:hover),
	.nav-desktop a:hover,
	.nav-menu-link:hover,
	.nav-menu-download:hover {
		background-color: glass.$hover-background;
	}

	.nav-menu-copy {
		display: flex;
		flex-direction: column;
		flex: 1;
		min-width: 0;
	}

	.nav-menu-title {
		font-family: var(--font-serif);
		font-size: 1.75rem;
		line-height: var(--leading-copy);
	}

	.nav-menu-description {
		margin-top: var(--space-1);
		font-size: var(--text-small);
		line-height: var(--leading-body);
	}

	.nav-menu-arrow {
		display: inline-flex;
		flex-shrink: 0;
	}

	.nav-logo {
		font-family: var(--font-serif);
		font-size: var(--text-brand);
		font-weight: var(--weight-regular);
		line-height: var(--leading-heading);

		a {
			text-decoration: none;
			color: inherit;
		}
	}

	.nav-weekly-link {
		color: inherit;
		text-decoration: none;

		@include at-least(large) {
			display: none;
		}
	}

	.nav-desktop {
		display: none;

		@include at-least(large) {
			display: flex;
			gap: var(--space-2);
		}

		a {
			display: inline-flex;
			align-items: center;
			padding-inline: var(--space-4);
			color: inherit;
			text-decoration: none;
			white-space: nowrap;
		}

		.nav-desktop-download {
			gap: var(--space-2);
		}
	}

	.nav-bar :global(.nav-menu-toggle) {
		@include at-least(large) {
			display: none;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.nav-main,
		.nav-desktop a,
		.nav-menu-link,
		.nav-menu-download {
			transition: none;
		}
	}

	@include at-least(large) {
		.nav-backdrop,
		.nav-menu {
			display: none;
		}
	}
</style>
