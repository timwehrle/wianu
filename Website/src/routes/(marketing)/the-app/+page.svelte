<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '#lib/components/TextLink.svelte';
</script>

<svelte:head>
	<title>The App - Wianu</title>
	<meta
		name="description"
		content="I made Wianu to keep the streaming services I use, what I'm watching, and my watchlist in one place."
	/>
</svelte:head>

<div class="page-frame">
	<header class="hero">
		<h1>Everything you're watching,<br /><em>in one place.</em></h1>
		<div class="hero-bottom">
			<p>
				I made Wianu for the moment when you want to watch something but can't
				remember where it lives. Your services, current shows, and watchlist are
				together in one Mac app.
			</p>
			<TextLink href={resolve('download')}>Download for macOS</TextLink>
		</div>
	</header>

	<div class="app-image">
		<enhanced:img
			src="#lib/assets/wianu-app.png"
			alt="Wianu showing streaming sites, Continue Watching, and a watchlist in one window"
		/>
	</div>

	<section
		class="features"
		aria-label="What Wianu brings together"
	>
		<div class="feature">
			<h2>Your services,<br /><em>side by side.</em></h2>
			<p>
				The sites you already use are in one sidebar. Open one, switch to
				another, and get back to what you came for.
			</p>
		</div>
		<div class="feature">
			<h2>Remember what<br /><em>you started.</em></h2>
			<p>
				The shows and films you're in the middle of have a place of their own,
				so they're easier to find next time.
			</p>
		</div>
		<div class="feature">
			<h2>Keep the ones<br /><em>for later.</em></h2>
			<p>
				When someone mentions a film you want to see, add it to your watchlist.
				It'll be there when you have time.
			</p>
		</div>
	</section>

	<section
		class="download"
		aria-labelledby="download-title"
	>
		<h2 id="download-title">Give Wianu<br /><em>a try.</em></h2>
		<div class="download-bottom">
			<p>Made for macOS 26 or later.</p>
			<TextLink href={resolve('download')}>Download Wianu</TextLink>
		</div>
	</section>
</div>

<style lang="scss">
	.hero {
		min-height: 68svh;
		display: flex;
		flex-direction: column;
	}

	em {
		color: var(--accent);
		font-weight: var(--weight-regular);
	}

	h1 {
		margin-block: var(--space-fluid-lg);
		font-size: var(--text-display);
	}

	.hero-bottom,
	.download-bottom {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		align-items: end;
		gap: var(--space-6) var(--space-12);
	}

	.hero-bottom {
		margin-top: auto;
		padding-bottom: var(--space-fluid-lg);
	}

	.hero-bottom p {
		max-width: var(--measure-copy);
		font-size: var(--text-lead);
	}

	.app-image {
		:global(img) {
			border-radius: var(--radius-small);
			height: auto;
		}
	}

	.features {
		margin-top: var(--space-fluid-xl);
	}

	.feature {
		display: grid;
		gap: var(--space-6);
		padding-block: var(--space-fluid-md);
		border-top: var(--border-width) solid var(--border);
	}

	.feature h2 {
		font-size: var(--text-heading-large);
	}

	.feature p {
		max-width: var(--measure-short);
		font-size: var(--text-body-large);
	}

	.download {
		margin-top: var(--space-fluid-lg);
		border-top: var(--border-width) solid var(--border-strong);
	}

	.download h2 {
		margin-block: var(--space-fluid-md);
		font-size: var(--text-display);
	}

	.download-bottom p {
		color: var(--muted-foreground);
	}

	@include at-least(medium) {
		.app-image {
			margin-left: var(--space-fluid-lg);
		}

		.feature {
			grid-template-columns: minmax(0, 1fr) minmax(16rem, 0.75fr);
			align-items: start;
		}

		.feature p {
			padding-top: var(--space-2);
		}
	}
</style>
