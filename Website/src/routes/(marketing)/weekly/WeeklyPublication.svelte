<script lang="ts">
	import type { WeeklyEntry, WeeklySelectionMovie } from '#lib/weekly/types.js';
	import WeeklyArchive from './WeeklyArchive.svelte';
	import WeeklyCover from './WeeklyCover.svelte';
	import WeeklyFilm from './WeeklyFilm.svelte';

	let {
		movies,
		selection,
		archive
	}: {
		movies: WeeklySelectionMovie[];
		selection: WeeklyEntry | null;
		archive: WeeklyEntry[];
	} = $props();
</script>

<section
	class="weekly-publication"
	aria-labelledby="weekly-title"
>
	<WeeklyCover {selection} />

	{#if movies.length === 0}
		<p class="empty-state">This week's films are coming soon.</p>
	{:else}
		<ol class="films">
			{#each movies as movie, index (movie.id)}
				<WeeklyFilm
					{movie}
					{index}
				/>
			{/each}
		</ol>
	{/if}

	{#if archive.length > 1}
		<WeeklyArchive
			{archive}
			{selection}
		/>
	{/if}
</section>

<style lang="scss">
	.weekly-publication {
		background: var(--background);
		color: var(--foreground);
		padding: var(--page-top) var(--page-gutter) var(--space-fluid-lg);
	}

	.empty-state,
	.films {
		max-width: var(--content-width);
		margin-inline: auto;
	}

	.empty-state {
		padding: var(--space-20) 0;
		border-top: var(--border-width) solid var(--border);
		font-family: var(--font-serif);
		font-size: var(--text-heading-small);
	}

	.films {
		list-style: none;
	}
</style>
