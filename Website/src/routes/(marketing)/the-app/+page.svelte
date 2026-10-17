<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '#lib/components/TextLink.svelte';
	import Button from '#lib/components/Button.svelte';
	import servicesImage from '#lib/assets/app-services.png';
	import watchingImage from '#lib/assets/app-continue-watching.png';
	import watchlistImage from '#lib/assets/app-watchlist.png';
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
			<div class="download-action">
				<Button
					href={resolve('download')}
					data-sveltekit-reload
					target="_blank"
					rel="noopener noreferrer">Download for macOS</Button
				>
				<span>macOS 26 or later</span>
			</div>
		</div>
	</header>

	<div class="app-image">
		<enhanced:img
			src="#lib/assets/wianu-app.png"
			alt="Wianu showing streaming sites, Continue Watching, and a watchlist in one window"
			loading="eager"
			fetchpriority="high"
		/>
	</div>

	<section
		class="features"
		aria-label="What Wianu brings together"
	>
		<div class="feature">
			<div class="feature-copy">
				<h2>Your services,<br /><em>side by side.</em></h2>
				<p>
					The sites you already use are in one sidebar. Open one, switch to
					another, and get back to what you came for.
				</p>
			</div>
			<div class="feature-visual">
				<div
					class="feature-detail"
					style:max-width="232px"
				>
					<img
						src={servicesImage}
						width="464"
						height="526"
						alt="Streaming services together in the Wianu sidebar"
						loading="lazy"
					/>
				</div>
			</div>
		</div>
		<div class="feature">
			<div class="feature-copy">
				<h2>Remember what<br /><em>you started.</em></h2>
				<p>
					The shows and films you're in the middle of have a place of their own,
					so they're easier to find next time.
				</p>
			</div>
			<div class="feature-visual">
				<div
					class="feature-detail"
					style:max-width="229px"
				>
					<img
						src={watchingImage}
						width="458"
						height="214"
						alt="Continue Watching in Wianu, showing saved shows and films"
						loading="lazy"
					/>
				</div>
			</div>
		</div>
		<div class="feature">
			<div class="feature-copy">
				<h2>Keep the ones<br /><em>for later.</em></h2>
				<p>
					When someone mentions a film you want to see, add it to your
					watchlist. It'll be there when you have time.
				</p>
			</div>
			<div class="feature-visual">
				<div
					class="feature-detail feature-watchlist"
					style:max-width="227px"
				>
					<img
						src={watchlistImage}
						width="454"
						height="596"
						alt="The Wianu watchlist with films saved for later"
						loading="lazy"
					/>
				</div>
			</div>
		</div>
	</section>

	<section
		class="maker"
		aria-labelledby="maker-title"
	>
		<h2 id="maker-title">Made by <em>Tim.</em></h2>
		<div class="maker-copy">
			<p>
				I'm Tim Wehrle, an independent software developer from Germany. I built
				Wianu because I kept losing track of what I was watching across
				streaming services. It's the Mac app I wanted for my own everyday
				watching.
			</p>
			<div class="maker-links">
				<TextLink
					href="https://github.com/timwehrle"
					target="_blank"
					rel="noopener noreferrer">GitHub</TextLink
				>
				<TextLink
					href="https://www.timwehrle.de"
					target="_blank"
					rel="noopener noreferrer">Personal website</TextLink
				>
				<a
					class="support-link"
					href="https://ko-fi.com/timwehrle"
					target="_blank"
					rel="noopener noreferrer">Support my work</a
				>
			</div>
		</div>
	</section>

	<section
		class="download"
		aria-labelledby="download-title"
	>
		<h2 id="download-title">Give Wianu<br /><em>a try.</em></h2>
		<div class="download-bottom">
			<p>Your next film is waiting.</p>
			<div class="download-action">
				<Button
					href={resolve('download')}
					data-sveltekit-reload
					target="_blank"
					rel="noopener noreferrer">Download Wianu</Button
				>
				<span>macOS 26 or later</span>
			</div>
		</div>
	</section>
</div>

<style lang="scss">
	.hero {
		display: flex;
		flex-direction: column;
	}

	em {
		color: var(--accent);
		font-weight: var(--weight-regular);
	}

	h1 {
		margin-block: var(--space-fluid-sm) var(--space-fluid-md);
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
		padding-bottom: var(--space-fluid-lg);
	}

	.hero-bottom p {
		max-width: var(--measure-copy);
		font-size: var(--text-lead);
	}

	.app-image {
		padding: clamp(var(--space-4), 4vw, var(--space-16));
		background: color-mix(in srgb, var(--background) 96%, var(--foreground));
		border-radius: var(--radius-small);

		:global(img) {
			display: block;
			width: 100%;
			border-radius: var(--radius-small);
			height: auto;
			box-shadow: 0 18px 45px #00000024;
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
		margin-bottom: var(--space-6);
	}

	.feature p {
		max-width: var(--measure-short);
		font-size: var(--text-body-large);
	}

	.maker {
		display: grid;
		gap: var(--space-6);
		margin-top: var(--space-fluid-lg);
		padding-block: var(--space-fluid-md);
		border-top: var(--border-width) solid var(--border-strong);
	}

	.maker h2 {
		font-size: var(--text-heading-large);
	}

	.maker-copy p {
		max-width: var(--measure-short);
		font-size: var(--text-body-large);
	}

	.maker-links {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-4) var(--space-6);
		margin-top: var(--space-6);
		align-items: center;
	}

	.support-link {
		color: var(--foreground);
		text-decoration: underline;
		text-underline-offset: 0.2em;

		&:hover {
			color: var(--accent-text);
		}
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
		.feature,
		.maker {
			grid-template-columns: minmax(0, 1fr) minmax(16rem, 0.75fr);
			align-items: start;
		}

		.feature {
			grid-template-columns: minmax(0, 0.9fr) minmax(0, 1fr);
			align-items: center;
			gap: var(--space-fluid-md);
		}

		.feature:nth-child(2) .feature-copy {
			grid-column: 2;
			grid-row: 1;
		}
		.feature:nth-child(2) .feature-visual {
			grid-column: 1;
			grid-row: 1;
		}
	}
	.feature-visual {
		display: grid;
		place-items: center;
		min-width: 0;
		min-height: 20rem;
		padding: var(--space-8);
		background: color-mix(in srgb, var(--background) 97%, var(--foreground));
		border-radius: var(--radius-small);
	}

	.feature-detail {
		width: 100%;
		overflow: hidden;
		border-radius: var(--radius-small);
		box-shadow: 0 12px 30px #0000001f;

		:global(img) {
			display: block;
			width: 100%;
			height: auto;
		}
	}

	.feature-watchlist {
		max-height: 16.25rem;
	}

	.download-action {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-3);

		span {
			color: var(--muted-foreground);
			font-size: var(--text-small);
		}
	}
</style>
