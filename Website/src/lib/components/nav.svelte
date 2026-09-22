<script lang="ts">
	import { resolve } from '$app/paths';

	let isOpen = $state(false);
	let menuTrigger: HTMLButtonElement;
	let menu: HTMLElement;

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
			!menu.contains(event.target as Node)
		) {
			closeMenu();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} onpointerdown={handlePointerdown} />

<header>
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
				Menu
			</button>
			<nav bind:this={menu} class="nav-menu" aria-label="Site navigation" hidden={!isOpen}>
				<ul class="nav-list">
					<li><a class="nav-menu-link" href="#" onclick={closeMenu}>The App</a></li>
					<li><a class="nav-menu-link" href="#" onclick={closeMenu}>About</a></li>
				</ul>
			</nav>
		</div>
	</div>
</header>

<style lang="scss">
	header {
		position: relative;
		z-index: 10;
	}

	.nav-container {
		padding: 1rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.nav-actions {
		position: relative;
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.nav-menu {
		position: absolute;
		inset-block-start: calc(100% + 0.5rem);
		inset-inline-end: 0;
		min-width: 11rem;
		padding: 0.75rem;
		background: #fafafa;
		color: #000;
		border-radius: 0.75rem;
		box-shadow: 0 0.75rem 2rem rgb(0 0 0 / 20%);
	}

	.nav-menu-link {
		text-decoration: none;
		color: inherit;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.nav-logo {
		font-family: var(--font-serif);

		a {
			text-decoration: none;
			color: inherit;
		}
	}

	.nav-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		list-style: none;
	}

	.nav-link {
		text-decoration: none;
		color: inherit;
	}

	.nav-trigger {
		color: inherit;
		background-color: transparent;
		width: 32px;
		height: 32px;
		border: 0;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
	}
</style>
