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
		--weekly-background: var(--background);
		--weekly-foreground: var(--foreground);
		--weekly-border: #242321;
		--weekly-muted: #e8e6e1;
		--weekly-quiet: #716f6a;
		--weekly-rule: #cbc9c3;
		--weekly-accent: var(--accent);
		--weekly-image-placeholder: #e5e3df;
		--weekly-overview: #56544e;
		background: var(--weekly-background);
		color: var(--weekly-foreground);
		padding: 7rem var(--page-gutter) 6rem;

		@include at-least(medium) {
			padding-top: 8rem;
		}
	}

	.empty-state,
	.films {
		max-width: var(--page-width);
		margin-inline: auto;
	}

	.empty-state {
		padding: 5rem 0;
		border-top: 1px solid var(--weekly-rule);
		font-family: var(--font-serif);
		font-size: 2rem;
	}

	.films {
		list-style: none;
	}
</style>
