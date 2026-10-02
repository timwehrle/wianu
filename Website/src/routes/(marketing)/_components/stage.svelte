<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '#lib/components/text-link.svelte';
</script>

<section class="stage">
	<div class="stage-copy">
		<h1 class="stage-title">All your streaming. <br /><em>One home.</em></h1>
		<p>
			Your streaming services, watchlist and a curated selection of films.
			Together in one native Mac app.
		</p>
		<div>
			<TextLink href={resolve('download')}>Download for macOS</TextLink>
		</div>
	</div>
	<div class="stage-img-wrapper">
		<enhanced:img
			class="stage-img"
			src="#lib/assets/wianu-app.png"
			alt="A screenshot of the Wianu app"
		></enhanced:img>
	</div>
</section>

<style lang="scss">
	.stage {
		overflow: hidden;
		padding-block: 7rem clamp(4rem, 8vw, 8rem);
	}

	.stage-copy {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		max-width: var(--page-width);
		margin-inline: auto;
		padding: 0 var(--page-gutter) clamp(3rem, 6vw, 6rem);

		p {
			max-width: 35rem;
		}
	}

	.stage-title {
		margin-top: clamp(2rem, 5vw, 5rem);
		font-family: var(--font-serif);
		font-size: clamp(3.75rem, 8vw, 8.5rem);
		font-weight: 400;
		line-height: 1;

		em {
			color: var(--accent);
			font-weight: 400;
		}
	}

	.stage-img-wrapper {
		max-width: var(--page-width);
		margin-inline: auto;
		padding-inline: var(--page-gutter);
		overflow: hidden;
	}

	.stage-img {
		position: relative;
		width: 100%;
		min-width: 37.5rem;
		height: auto;

		@include at-least(medium) {
			min-width: 0;
			width: calc(100% - clamp(3rem, 7vw, 7rem));
			margin-left: clamp(3rem, 7vw, 7rem);
		}
	}
</style>
