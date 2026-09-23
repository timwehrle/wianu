<script lang="ts">
	import { resolve } from '$app/paths';
	import { prefersReducedMotion } from 'svelte/motion';
	import { slide } from 'svelte/transition';

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

<header>
	<div class="nav-shell">
		<div class="nav-container">
			<h1 class="nav-logo"><a href={resolve('/')} onclick={closeMenu}>Wianu</a></h1>
			<div class="nav-actions">
				<a class="nav-link" href="#" onclick={closeMenu}>Weekly</a>
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
							<span class="nav-menu-arrow" aria-hidden="true">→</span>
						</a>
					</li>
					<li>
						<a class="nav-menu-link" href="#" onclick={closeMenu}>
							<span class="nav-menu-copy">
								<span class="nav-menu-title">About</span>
								<span class="nav-menu-description">The idea behind Wianu</span>
							</span>
							<span class="nav-menu-arrow" aria-hidden="true">→</span>
						</a>
					</li>
				</ul>
			</nav>
		{/if}
	</div>
</header>

<style lang="scss">
	header {
		position: fixed;
		width: 100%;
		z-index: 10;
	}

	.nav-shell {
		margin: 0.75rem;
		color: #f2eee6;
	}

	.nav-container {
		padding: 0.75rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		background-color: #292929;
		border-radius: 6px;
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
		background-color: #292929;
		border-radius: 6px;
		padding-block: 1.25rem;
		padding-inline: 1rem;
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
		color: #b5b0a8;
	}

	.nav-menu-arrow {
		position: relative;
		align-self: start;
		font-size: 1.25rem;
		line-height: 1;
		color: #d8b988;
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
		color: #292929;
		background-color: #d8b988;
		border: 1px solid #d8b988;
		border-radius: 3px;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
	}
</style>
