<script lang="ts">
	import WianuAppImage from '$lib/assets/wianu-app.png?enhanced';
</script>

<section class="stage">
	<div class="stage-copy">
		<h2 class="stage-title">All your streaming. <br />One home.</h2>
		<p>
			Your streaming services, watchlist and a curated selection of films. Together in one native
			Mac app.
		</p>
	</div>
	<div class="stage-img-wrapper">
		<enhanced:img class="stage-img" src={WianuAppImage} alt="A screenshot of the Wianu app" />
	</div>
</section>

<style lang="scss">
	.stage {
		overflow: hidden;
	}

	.stage-copy {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 7rem 1rem 1rem;
	}

	.stage-title {
		font-size: clamp(2.5rem, 1.5rem + 4vw, 5rem);
		font-weight: 600;
	}

	.stage-img {
		position: relative;
		min-width: 700px;
		height: auto;
	}
</style>
