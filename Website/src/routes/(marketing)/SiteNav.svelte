<script lang="ts">
	import { resolve } from '$app/paths';
	import { prefersReducedMotion } from 'svelte/motion';
	import { fade, slide } from 'svelte/transition';
	import { ArrowDownIcon, ArrowRightIcon } from '@lucide/svelte';

	let isOpen = $state(false);
	let menuTrigger: HTMLButtonElement;
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
			menuTrigger.focus();
		}
	}

	function handlePointerdown(event: PointerEvent) {
		if (
			isOpen &&
			!menuTrigger.contains(event.target as Node) &&
			!menu?.contains(event.target as Node)
		) {
			closeMenu();
		}
	}

	function handleResize() {
		if (isOpen && getComputedStyle(menuTrigger).display === 'none') {
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
				>
					Download
					<ArrowDownIcon
						size="var(--icon-size)"
						strokeWidth={1.5}
						aria-hidden="true"
					/>
				</a>
			</nav>
			<button
				bind:this={menuTrigger}
				class="nav-menu-toggle"
				type="button"
				aria-label={isOpen ? 'Close menu' : 'Open menu'}
				aria-expanded={isOpen}
				aria-controls="site-menu"
				onclick={toggleMenu}
			>
				<span>{isOpen ? 'Close' : 'Menu'}</span>
			</button>
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
									strokeWidth={1.5}
								/>
							</span>
						</a>
					</li>
					<li class="nav-menu-download-item">
						<a
							class="nav-menu-download"
							href={resolve('download')}
							data-sveltekit-reload
							onclick={closeMenu}
						>
							<span class="nav-menu-copy">
								<span class="nav-menu-description">For macOS 26 or later</span>
								<span class="nav-menu-title">Download Wianu</span>
							</span>
							<span
								class="nav-menu-arrow"
								aria-hidden="true"
							>
								<ArrowDownIcon
									size="var(--icon-size)"
									strokeWidth={1.5}
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
	.nav-backdrop {
		position: fixed;
		inset: 0;
		z-index: 9;
		backdrop-filter: blur(2px);
		background-color: var(--overlay);
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
		color: var(--foreground);
	}

	.nav-bar {
		display: flex;
		gap: var(--border-width);
	}

	.nav-main,
	.nav-desktop a,
	.nav-menu-toggle {
		background: var(--surface-glass);
		backdrop-filter: blur(20px) saturate(180%);
		-webkit-backdrop-filter: blur(20px) saturate(180%);
		border-radius: var(--radius-small);
	}

	.nav-main {
		padding: var(--space-3);
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex: 1;
		min-width: 0;
	}

	.nav-menu {
		padding-top: var(--border-width);
	}

	.nav-menu-list {
		display: flex;
		flex-direction: column;
		gap: var(--border-width);
		list-style: none;
	}

	.nav-menu-link {
		position: relative;
		display: flex;
		align-items: center;
		gap: var(--space-4);
		width: 100%;
		min-height: 7.5rem;
		overflow: hidden;
		text-decoration: none;
		color: inherit;
		background-color: var(--surface);
		border-radius: var(--radius-small);
		padding-block: var(--space-5);
		padding-inline: var(--space-4);
	}

	.nav-menu-download-item {
		background-color: var(--surface);
		border-radius: var(--radius-small);
	}

	.nav-menu-download {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-4);
		color: inherit;
		text-decoration: none;
		white-space: nowrap;
		width: 100%;

		.nav-menu-description {
			margin-block: 0 var(--space-1);
		}
	}

	.nav-menu-copy {
		position: relative;
		display: flex;
		flex-direction: column;
		flex: 1;
	}

	.nav-menu-title {
		font-family: var(--font-serif);
		font-size: var(--text-heading-small);
		line-height: var(--leading-heading);
	}

	.nav-menu-description {
		margin-top: var(--space-1);
		font-size: var(--text-small);
	}

	.nav-menu-arrow {
		position: relative;
		align-self: start;
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
		text-decoration: none;
		color: inherit;

		@include at-least(large) {
			display: none;
		}
	}

	.nav-desktop {
		display: none;

		@include at-least(large) {
			display: flex;
			gap: var(--border-width);
		}

		a {
			display: inline-flex;
			align-items: center;
			padding-inline: var(--space-4);
			color: inherit;
			text-decoration: none;
			white-space: nowrap;

			&:hover {
				text-decoration: underline;
				text-underline-offset: 0.25em;
			}
		}

		.nav-desktop-download {
			gap: var(--space-2);
		}
	}

	.nav-menu-toggle {
		min-height: var(--control-size);
		min-width: var(--control-size);
		padding: var(--space-3);
		color: inherit;
		font-weight: var(--weight-semibold);
		border: 0;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;

		@include at-least(large) {
			display: none;
		}
	}

	@include at-least(large) {
		.nav-backdrop,
		.nav-menu {
			display: none;
		}
	}

	.nav-shell:has(.nav-menu) {
		color: var(--foreground);

		.nav-main,
		.nav-menu-toggle,
		.nav-menu-link,
		.nav-menu-download-item {
			background: var(--background);
			backdrop-filter: none;
			-webkit-backdrop-filter: none;
		}
	}
</style>
