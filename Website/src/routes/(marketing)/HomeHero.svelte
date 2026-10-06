<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '#lib/components/TextLink.svelte';
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
		<div>
			<TextLink href={resolve('download')}>Download for macOS</TextLink>
		</div>
	</div>
	<div class="home-hero-image-wrapper page-container">
		<enhanced:img
			class="home-hero-image"
			src="#lib/assets/wianu-app.png"
			alt="A screenshot of the Wianu app"
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
		padding-bottom: var(--space-fluid-lg);

		p {
			max-width: var(--measure-copy);
			font-size: var(--text-lead);
		}
	}

	.home-hero-title {
		margin-top: var(--space-fluid-md);
		font-family: var(--font-serif);
		font-size: var(--text-display);
		font-weight: var(--weight-regular);
		line-height: var(--leading-heading);

		em {
			color: var(--accent);
			font-weight: var(--weight-regular);
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
