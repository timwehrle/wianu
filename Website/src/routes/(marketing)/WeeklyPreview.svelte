<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklySelectionMovie } from '#lib/weekly/types.js';
	import TextLink from '#lib/components/TextLink.svelte';
	import WeeklyList from './WeeklyList.svelte';

	let { movies }: { movies: WeeklySelectionMovie[] } = $props();
</script>

{#if movies.length > 0}
	<section
		class="weekly-preview"
		aria-labelledby="weekly-title"
	>
		<div class="weekly-container">
			<div class="weekly-heading">
				<h2 id="weekly-title">Wianu <em>Weekly</em></h2>
				<p>Five films worth your time, handpicked each week.</p>
			</div>

			<WeeklyList {movies} />
			<div class="weekly-link">
				<TextLink href={resolve('weekly')}>Explore this week</TextLink>
			</div>
		</div>
	</section>
{/if}

<style lang="scss">
	.weekly-preview {
		padding-block: clamp(4rem, 8vw, 6rem);
		background-color: var(--surface);
	}

	.weekly-container {
		max-width: var(--page-width);
		margin-inline: auto;
		padding-inline: var(--page-gutter);
	}

	.weekly-heading {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		margin-bottom: clamp(3rem, 6vw, 6rem);
		padding-top: clamp(2rem, 4vw, 4rem);

		p {
			max-width: 40rem;
		}
	}

	h2 {
		font-size: clamp(3.75rem, 9vw, 8rem);
		font-weight: 400;
		font-family: var(--font-serif);
		line-height: 1;

		em {
			color: var(--accent);
		}
	}

	.weekly-link {
		margin-top: clamp(3rem, 6vw, 6rem);
	}
</style>
