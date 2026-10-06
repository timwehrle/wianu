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
		font-weight: 400;
	}

	h1 {
		margin-block: clamp(3.5rem, 8vw, 7rem);
		font-size: clamp(4.25rem, 12vw, 11rem);
		line-height: 1;
	}

	.hero-bottom,
	.download-bottom {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		align-items: end;
		gap: 1.5rem 3rem;
	}

	.hero-bottom {
		margin-top: auto;
		padding-bottom: clamp(3rem, 6vw, 6rem);
	}

	.hero-bottom p {
		max-width: 35rem;
		font-size: clamp(1.25rem, 2vw, 1.75rem);
	}

	.app-image {
		margin-left: clamp(0rem, 7vw, 7rem);

		:global(img) {
			border-radius: 3px;
			height: auto;
		}
	}

	.features {
		margin-top: clamp(3.75rem, 7.5vw, 7.5rem);
	}

	.feature {
		display: grid;
		gap: 1.5rem;
		padding-block: clamp(2rem, 5vw, 4rem);
		border-top: 1px solid var(--border);
	}

	.feature h2 {
		font-size: clamp(2.5rem, 5vw, 5.5rem);
		line-height: 1;
	}

	.feature p {
		max-width: 25rem;
		font-size: 1.25rem;
	}

	.download {
		margin-top: clamp(3rem, 6vw, 6rem);
		border-top: 1px solid var(--foreground);
	}

	.download h2 {
		margin-block: clamp(2rem, 4vw, 4rem);
		font-size: clamp(3.75rem, 10vw, 9rem);
		line-height: 1;
	}

	.download-bottom p {
		color: var(--muted-foreground);
	}

	@include at-least(medium) {
		.feature {
			grid-template-columns: minmax(0, 1fr) minmax(16rem, 0.75fr);
			align-items: start;
		}

		.feature p {
			padding-top: 0.5rem;
		}
	}
</style>
