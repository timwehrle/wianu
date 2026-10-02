<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklySelectionMovie } from '$lib/server/weekly';
	import TextLink from '$lib/components/text-link.svelte';
	import WeeklyList from './weekly-list.svelte';

	let { movies }: { movies: WeeklySelectionMovie[] } = $props();
</script>

{#if movies.length > 0}
	<section
		class="weekly-preview"
		aria-labelledby="weekly-title"
	>
		<div class="weekly-container">
			<div class="weekly-heading">
				<div>
					<h2
						id="weekly-title"
						class="weekly-title"
					>
						Wianu <em>Weekly</em>
					</h2>
					<p>Five films worth your time, handpicked each week.</p>
				</div>
			</div>
			<WeeklyList {movies} />

			<div class="weekly-link">
				<TextLink href={resolve('/weekly')}>Explore this week</TextLink>
			</div>
		</div>
	</section>
{/if}

<style lang="scss">
	.weekly-preview {
		padding-block: 3rem;
		background-color: var(--surface);
	}

	.weekly-container {
		padding-inline: 1rem;
	}

	.weekly-heading {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 3rem;
	}

	h2 {
		font-size: clamp(3rem, 8vw, 6rem);
		font-weight: 400;
		margin-bottom: 0.5rem;
		font-family: var(--font-serif);
	}

	.weekly-link {
		margin-top: 2rem;
	}
</style>
