<script lang="ts">
	import { resolve } from '$app/paths';
	import { prefersReducedMotion } from 'svelte/motion';
	import { fade, slide } from 'svelte/transition';
	import { ArrowDownIcon, ArrowRightIcon } from '@lucide/svelte';
	import BrooksImage from '$lib/assets/brooks.jpg?enhanced';

	let isOpen = $state(false);
	let menuTrigger: HTMLButtonElement;
	let menu = $state<HTMLElement>();

	function toggleMenu() {
		isOpen = !isOpen;
	}

	function closeMenu() {
		if (isOpen) toggleMenu();
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
</script>

<svelte:window onkeydown={handleKeydown} onpointerdown={handlePointerdown} />

{#if isOpen}
	<div
		class="nav-backdrop"
		aria-hidden="true"
		transition:fade={{ duration: prefersReducedMotion.current ? 0 : 200 }}
	></div>
{/if}

<header>
	<div class="nav-shell">
		<div class="nav-container">
			<h1 class="nav-logo"><a href={resolve('/')} onclick={closeMenu}>Wianu</a></h1>
			<div class="nav-actions">
				<a class="nav-link" href={resolve('/weekly')} onclick={closeMenu}>Weekly</a>
				<button
					bind:this={menuTrigger}
					class="nav-trigger"
					type="button"
					aria-label={isOpen ? 'Close menu' : 'Open menu'}
					aria-expanded={isOpen}
					aria-controls="site-menu"
					onclick={toggleMenu}
				>
					<span>{isOpen ? 'Close' : 'Menu'}</span>
				</button>
			</div>
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
						<a class="nav-menu-link" href="#" onclick={closeMenu}>
							<span class="nav-menu-copy">
								<span class="nav-menu-title">The App</span>
								<span class="nav-menu-description">Meet your streaming home</span>
							</span>
							<span class="nav-menu-arrow" aria-hidden="true">
								<ArrowRightIcon strokeWidth={1} />
							</span>
						</a>
					</li>
					<li>
						<a class="nav-menu-link" href="#" onclick={closeMenu}>
							<span class="nav-menu-copy">
								<span class="nav-menu-title">About</span>
								<span class="nav-menu-description">The idea behind Wianu</span>
							</span>
							<span class="nav-menu-arrow" aria-hidden="true">
								<ArrowRightIcon />
							</span>
							<enhanced:img
								class="nav-menu-img"
								src={BrooksImage}
								alt="A picture of Louise Brooks, an American actress and dancer."
							/>
						</a>
					</li>
					<li class="nav-menu-download-item">
						<a
							class="nav-menu-download"
							href={resolve('/download')}
							data-sveltekit-reload
							onclick={closeMenu}
						>
							<span class="nav-menu-copy">
								<span class="nav-menu-description">For macOS 26 or later</span>
								<span class="nav-menu-title">Download Wianu</span>
							</span>
							<span class="nav-menu-arrow" aria-hidden="true">
								<ArrowDownIcon strokeWidth={1} aria-hidden="true" />
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
		background-color: rgb(0 0 0 / 25%);
	}

	header {
		position: fixed;
		width: 100%;
		z-index: 10;
	}

	.nav-shell {
		margin: 0.75rem;
		color: #1d1d1f;
	}

	.nav-container {
		padding: 0.75rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		background-color: #f5f5f7;
		border-radius: 3px;
	}

	.nav-actions {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.nav-menu {
		padding-top: 1px;
	}

	.nav-menu-list {
		display: flex;
		flex-direction: column;
		gap: 1px;
		list-style: none;
	}

	.nav-menu-link {
		position: relative;
		display: flex;
		align-items: center;
		gap: 1rem;
		width: 100%;
		min-height: 7.5rem;
		overflow: hidden;
		text-decoration: none;
		color: inherit;
		background-color: #f5f5f7;
		border-radius: 3px;
		padding-block: 1.25rem;
		padding-inline: 1rem;
	}

	.nav-menu-download-item {
		background-color: #f5f5f7;
		border-radius: 3px;
	}

	.nav-menu-download {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem;
		color: inherit;
		text-decoration: none;
		white-space: nowrap;
		width: 100%;

		.nav-menu-description {
			margin-block: 0 0.35rem;
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
		font-size: clamp(2rem, 4vw, 3rem);
		line-height: 1;
		transition: color 180ms ease;
	}

	.nav-menu-description {
		margin-top: 0.35rem;
		font-size: 0.8rem;
	}

	.nav-menu-img {
		position: absolute;
		inset: 0 0 0 auto;
		width: 42%;
		height: 100%;
		object-fit: cover;
		clip-path: polygon(38% 0, 100% 0, 100% 100%, 0 100%);
	}

	.nav-menu-arrow {
		position: relative;
		align-self: start;
	}

	.nav-logo {
		font-family: var(--font-serif);
		font-size: 2rem;
		font-weight: 400;

		a {
			text-decoration: none;
			color: inherit;
		}
	}

	.nav-link {
		text-decoration: none;
		color: inherit;
	}

	.nav-trigger {
		padding: 0.5rem;
		color: inherit;
		background-color: transparent;
		font-weight: 600;
		border: 0;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
	}
</style>
