<script lang="ts">
	import { resolve } from '$app/paths';
	import Button from '#lib/components/Button.svelte';
</script>

<section class="home-hero">
	<div class="home-hero-copy page-container">
		<h1 class="home-hero-title">
			All your streaming. <br /><em>One home.</em>
		</h1>
		<p>
			Your streaming services, watchlist and a curated selection of films.
			Together in one native Mac app.
		</p>
		<div class="hero-actions">
			<div class="hero-download">
				<Button
					href={resolve('download')}
					data-sveltekit-reload
					target="_blank"
					rel="noopener noreferrer">Download for macOS</Button
				>
				<span>macOS 26 or later</span>
			</div>
			<a
				class="hero-app-link"
				href={resolve('the-app')}>Explore the app</a
			>
		</div>
	</div>
	<div class="home-hero-image-wrapper page-container">
		<enhanced:img
			class="home-hero-image"
			src="#lib/assets/wianu-app.png"
			alt="A screenshot of the Wianu app"
			fetchpriority="high"
		></enhanced:img>
	</div>
</section>

<style lang="scss">
	.home-hero {
		overflow: hidden;
		padding-block: var(--page-top) var(--space-fluid-xl);
	}

	.home-hero-copy {
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
		padding-bottom: var(--space-fluid-md);

		p {
			max-width: var(--measure-copy);
			font-size: var(--text-lead);
		}
	}

	.home-hero-title {
		margin-top: var(--space-fluid-sm);
		font-family: var(--font-serif);
		font-size: var(--text-display);
		font-weight: var(--weight-regular);
		line-height: var(--leading-heading);

		em {
			color: var(--accent);
			font-weight: var(--weight-regular);
		}
	}

	.hero-actions {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: var(--space-5) var(--space-6);
	}

	.hero-download {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-3);

		span {
			color: var(--muted-foreground);
			font-size: var(--text-small);
		}
	}

	.hero-app-link {
		color: var(--muted-foreground);
		text-decoration: underline;
		text-underline-offset: 0.25em;

		&:hover {
			color: var(--foreground);
		}
	}

	.home-hero-image-wrapper {
		overflow: hidden;
	}

	.home-hero-image {
		position: relative;
		width: 100%;
		min-width: 37.5rem;
		height: auto;

		@include at-least(medium) {
			min-width: 0;
			width: calc(100% - var(--space-fluid-lg));
			margin-left: var(--space-fluid-lg);
		}
	}
</style>
