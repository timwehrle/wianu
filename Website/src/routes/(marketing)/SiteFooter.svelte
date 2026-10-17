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
				<p class="footer-signoff">
					Made by <a
						href="https://www.timwehrle.de"
						target="_blank"
						rel="noopener noreferrer">Tim</a
					> in Germany.
				</p>
			</div>
			<div class="footer-columns">
				<nav aria-label="Footer navigation">
					<h2>Wianu</h2>
					<a href={resolve('the-app')}>The App</a>
					<a href={resolve('weekly')}>Weekly</a>
					<a
						href={resolve('download')}
						data-sveltekit-reload
						target="_blank"
						rel="noopener noreferrer">Download for macOS</a
					>
				</nav>
				<nav aria-label="Elsewhere">
					<h2>Elsewhere</h2>
					<a
						href="https://www.timwehrle.de"
						target="_blank"
						rel="noopener noreferrer">Personal website</a
					>
					<a
						href="https://github.com/timwehrle"
						target="_blank"
						rel="noopener noreferrer">GitHub</a
					>
				</nav>
			</div>
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
		padding-block: var(--space-12);
		border-top: var(--border-width) solid var(--border-strong);

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

	.footer-signoff {
		margin-top: var(--space-3);
		color: var(--muted-foreground);
	}

	.footer-columns {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: var(--space-6) var(--space-fluid-lg);
	}

	.footer-main nav {
		display: flex;
		flex-direction: column;
		align-items: start;
		gap: var(--space-3);

		h2 {
			margin-bottom: var(--space-2);
			font-family: var(--font-sans);
			font-size: var(--text-small);
			font-weight: var(--weight-semibold);
			line-height: var(--leading-body);
			letter-spacing: normal;
		}
	}

	.footer a {
		color: inherit;
		text-underline-offset: 0.2em;
		text-decoration: none;

		&:hover {
			text-decoration: underline;
		}
	}

	.footer .footer-brand:hover {
		text-decoration: none;
	}

	.footer-signoff a {
		text-decoration: underline;
	}

	.footer-bottom {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		gap: var(--space-4) var(--space-6);
		padding-top: var(--space-5);
		border-top: var(--border-width) solid var(--border);
		font-size: var(--text-small);
		color: var(--muted-foreground);
	}

	.footer-bottom nav {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-4) var(--space-6);
	}

	.footer-bottom :global(.button-link) {
		text-decoration: none;
		line-height: inherit;

		&:hover {
			text-decoration: underline;
		}
	}
</style>
