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
	h1,
	h2 {
		font-family: var(--font-serif);
		font-weight: 400;
	}

	em {
		color: var(--accent);
		font-weight: 400;
	}

	.intro h1 {
		margin-block: clamp(3rem, 7vw, 7rem);
		font-size: clamp(3.75rem, 10vw, 9.5rem);
		line-height: 1;
	}

	.story {
		max-width: 48rem;
		margin-left: auto;
		padding-block: clamp(2rem, 5vw, 5rem) clamp(5rem, 10vw, 10rem);
		border-top: 1px solid var(--border);
	}

	.story p {
		font-size: clamp(1.25rem, 2.4vw, 2rem);
	}

	.story p + p {
		margin-top: 1.75rem;
	}

	.story .story-beat {
		font-family: var(--font-serif);
		font-size: clamp(2rem, 4vw, 3rem);
		line-height: 1.25;
	}

	.two-parts,
	.maker {
		border-top: 1px solid var(--foreground);
	}

	.two-parts h2,
	.maker h2 {
		margin-block: clamp(3rem, 6vw, 6rem);
		font-size: clamp(3.75rem, 9vw, 8.5rem);
		line-height: 0.9;
	}

	.two-parts h2 span {
		color: var(--accent);
	}

	.part-grid {
		display: grid;
		gap: 2rem;
		padding-bottom: clamp(5rem, 10vw, 10rem);

		@include at-least(medium) {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	.part {
		display: flex;
		flex-direction: column;
		align-items: start;
		gap: 1.5rem;
	}

	.part p {
		max-width: 27rem;
		font-family: var(--font-serif);
		font-size: clamp(2rem, 3.5vw, 3.5rem);
		line-height: 1;
	}

	.maker {
		min-height: 20rem;
	}

	.maker > p:last-child {
		max-width: 25rem;
		margin-left: auto;
		font-size: 1.25rem;
	}
</style>
