<script lang="ts">
	import { resolve } from '$app/paths';
	import { onMount } from 'svelte';
	import Button from '#lib/components/Button.svelte';
	import { openPrivacySettings } from '#lib/privacy/analytics.js';

	const year = new Date().getFullYear();
	let interactive = $state(false);
	onMount(() => {
		interactive = true;
	});
</script>

<footer class="footer">
	<div class="footer-content page-container">
		<div class="footer-main">
			<div>
				<a
					class="footer-brand"
					href={resolve('')}>Wianu</a
				>
				<p>All your streaming. One home.</p>
			</div>
			<nav aria-label="Footer navigation">
				<a href={resolve('the-app')}>The App</a>
				<a href={resolve('weekly')}>Weekly</a>
				<a
					href={resolve('download')}
					data-sveltekit-reload
					target="_blank"
					rel="noopener noreferrer">Download for macOS</a
				>
			</nav>
		</div>
		<div class="footer-bottom">
			<p>© {year} Wianu</p>
			<nav aria-label="Legal navigation">
				<a href={resolve('privacy-policy')}>Privacy policy</a>
				<a href={resolve('imprint')}>Imprint</a>
				{#if interactive}
					<Button
						variant="link"
						id="privacy-settings-trigger"
						onclick={openPrivacySettings}>Privacy settings</Button
					>
				{:else}
					<a href={resolve('privacy-policy#analytics-settings')}
						>Privacy settings</a
					>
				{/if}
			</nav>
		</div>
	</div>
</footer>

<style lang="scss">
	.footer {
		padding-block: var(--space-12) var(--space-6);
		background: var(--background);
		color: var(--foreground);
	}

	.footer-main {
		display: flex;
		flex-direction: column;
		gap: var(--space-8);
		padding-bottom: var(--space-12);

		@include at-least(medium) {
			flex-direction: row;
			justify-content: space-between;
		}
	}

	.footer-brand {
		font-family: var(--font-serif);
		font-size: var(--text-heading);
		line-height: var(--leading-heading);
		text-decoration: none;
	}

	.footer-main p {
		margin-top: var(--space-3);
	}

	.footer-main nav {
		display: flex;
		flex-wrap: wrap;
		align-items: start;
		gap: var(--space-3) var(--space-6);
	}

	.footer a {
		color: inherit;
		text-underline-offset: 0.2em;
	}

	.footer-bottom {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		gap: var(--space-4) var(--space-6);
		padding-top: var(--space-5);
		border-top: var(--border-width) solid var(--border);
		font-size: var(--text-small);
	}

	.footer-bottom nav {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-4) var(--space-6);
	}
</style>
