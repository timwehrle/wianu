<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '#lib/components/text-link.svelte';
</script>

<section class="stage">
	<div class="stage-copy">
		<h2 class="stage-title">All your streaming. <br />One home.</h2>
		<p>
			Your streaming services, watchlist and a curated selection of films.
			Together in one native Mac app.
		</p>
		<TextLink href={resolve('download')}>Download for macOS</TextLink>
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
		padding-block: 7rem 3rem;
	}

	.stage-copy {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		padding: 0 1rem 1.5rem;
	}

	.stage-title {
		font-size: clamp(2.5rem, 1.5rem + 4vw, 5rem);
		font-weight: 500;
	}

	.stage-img-wrapper {
		padding-inline: 1rem;
	}

	.stage-img {
		position: relative;
		min-width: 700px;
		height: auto;
	}
</style>
