<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '#lib/components/TextLink.svelte';
</script>

<svelte:head>
	<title>About - Wianu</title>
	<meta
		name="description"
		content="Why I made Wianu: one place for what I'm watching, and five films to share each week."
	/>
</svelte:head>

<div class="page-frame">
	<header class="intro">
		<h1>I wanted watching<br />to feel <em>simple again.</em></h1>
	</header>

	<section
		class="story"
		aria-label="Why Wianu exists"
	>
		<p>
			I use more than one streaming service, and I kept losing track of what I
			was watching and where it lived.
		</p>
		<p class="story-beat">
			I'd open a few tabs,<br />
			check a few lists,<br />
			and still spend too long deciding.
		</p>
		<p>
			So I started making Wianu. I wanted my services, the titles I'd started,
			and the films I was saving for later to sit together. It's the app I
			wished I could open when I sat down to watch something.
		</p>
		<p>
			I also wanted a place to share films I care about. Every week I pick five
			for Wianu Weekly and write a little about why each one stayed with me.
		</p>
	</section>

	<section
		class="two-parts"
		aria-labelledby="two-parts-title"
	>
		<h2 id="two-parts-title">Wianu <span>+</span> <em>Weekly</em></h2>
		<div class="part-grid">
			<div class="part">
				<p>The Mac app I wanted for my everyday watching.</p>
				<TextLink href={resolve('the-app')}>Explore the app</TextLink>
			</div>
			<div class="part">
				<p>Five films I'd like to share with you each week.</p>
				<TextLink href={resolve('weekly')}>Read Wianu Weekly</TextLink>
			</div>
		</div>
	</section>

	<section
		class="maker"
		aria-labelledby="maker-title"
	>
		<h2 id="maker-title">Made by <em>Tim.</em></h2>
		<p>
			I'm Tim Wehrle, a software developer from Germany. I build Wianu because I
			love films, and I think finding one to watch should be part of the
			pleasure.
		</p>
	</section>
</div>

<style lang="scss">
	em {
		color: var(--accent);
		font-weight: var(--weight-regular);
	}

	.intro h1 {
		margin-block: var(--space-fluid-lg);
		font-size: var(--text-display);
	}

	.story {
		max-width: var(--measure-prose);
		margin-left: auto;
		padding-block: var(--space-fluid-md) var(--space-section);
		border-top: var(--border-width) solid var(--border);
	}

	.story p {
		font-size: var(--text-lead);
	}

	.story p + p {
		margin-top: var(--space-8);
	}

	.story .story-beat {
		font-family: var(--font-serif);
		font-size: var(--text-heading-small);
		line-height: var(--leading-copy);
	}

	.two-parts,
	.maker {
		border-top: var(--border-width) solid var(--border-strong);
	}

	.two-parts h2,
	.maker h2 {
		margin-block: var(--space-fluid-lg);
		font-size: var(--text-heading-display);
	}

	.two-parts h2 span {
		color: var(--accent);
	}

	.part-grid {
		display: grid;
		gap: var(--space-8);
		padding-bottom: var(--space-section);

		@include at-least(medium) {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	.part {
		display: flex;
		flex-direction: column;
		align-items: start;
		gap: var(--space-6);
	}

	.part p {
		max-width: var(--measure-short);
		font-family: var(--font-serif);
		font-size: var(--text-deck);
		line-height: var(--leading-heading);
	}

	.maker {
		min-height: 20rem;
	}

	.maker > p:last-child {
		max-width: var(--measure-short);
		margin-left: auto;
		font-size: var(--text-body-large);
	}
</style>
