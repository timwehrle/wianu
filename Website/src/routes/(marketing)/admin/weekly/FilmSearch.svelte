<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklyMovie } from '#lib/weekly/types.js';
	import { SearchIcon } from '@lucide/svelte';

	let {
		selectedIds,
		atLimit,
		onAdd
	}: {
		selectedIds: number[];
		atLimit: boolean;
		onAdd: (movie: WeeklyMovie) => void;
	} = $props();

	let query = $state('');
	let results = $state<WeeklyMovie[]>([]);
	let searching = $state(false);
	let searched = $state(false);
	let searchError = $state('');

	async function search(event: SubmitEvent) {
		event.preventDefault();
		if (!query.trim()) {
			return;
		}

		searching = true;
		searchError = '';
		try {
			const response = await fetch(
				`${resolve('v1/search/multi')}?query=${encodeURIComponent(query.trim())}`
			);

			if (!response.ok) {
				throw new Error('Search is unavailable right now.');
			}

			const body = await response.json();
			results = (body.results ?? [])
				.filter(
					(item: Record<string, unknown>) =>
						item.media_type === 'movie' && Number.isSafeInteger(item.id)
				)
				.map((item: Record<string, unknown>) => ({
					id: item.id as number,
					title: typeof item.title === 'string' ? item.title : 'Untitled',
					releaseDate:
						typeof item.release_date === 'string' ? item.release_date : '',
					overview: typeof item.overview === 'string' ? item.overview : '',
					posterPath:
						typeof item.poster_path === 'string' ? item.poster_path : null,
					backdropPath:
						typeof item.backdrop_path === 'string' ? item.backdrop_path : null
				}));
			searched = true;
		} catch (error) {
			searchError = error instanceof Error ? error.message : 'Search failed.';
		} finally {
			searching = false;
		}
	}
</script>

<section
	class="film-search"
	aria-labelledby="film-search-title"
>
	<h2
		class="admin-heading"
		id="film-search-title"
	>
		Find a film
	</h2>
	<form onsubmit={search}>
		<label for="movie-search">Movie title</label>
		<div class="search-fields">
			<input
				class="admin-field"
				id="movie-search"
				bind:value={query}
				placeholder="Search by title"
			/>
			<button
				class="admin-action"
				type="submit"
				disabled={searching}
			>
				<SearchIcon
					size="var(--icon-size)"
					strokeWidth={1.5}
					aria-hidden="true"
				/>
				{searching ? 'Searching…' : 'Search'}
			</button>
		</div>
	</form>
	{#if searchError}<p
			class="message"
			role="alert"
		>
			{searchError}
		</p>{/if}
	{#if searched && !searchError && results.length === 0}<p class="empty">
			No films found. Try another title.
		</p>{/if}
	{#if results.length > 0}
		<ul
			class="results"
			aria-label="Search results"
		>
			{#each results as movie (movie.id)}
				<li>
					{#if movie.posterPath}
						<img
							src={`https://image.tmdb.org/t/p/w92${movie.posterPath}`}
							alt=""
							loading="lazy"
						/>
					{:else}
						<div
							class="poster-placeholder"
							aria-hidden="true"
						></div>
					{/if}
					<div class="film-info">
						<h3>{movie.title}</h3>
						{#if movie.releaseDate}<p>{movie.releaseDate.slice(0, 4)}</p>{/if}
					</div>
					<button
						type="button"
						disabled={atLimit || selectedIds.includes(movie.id)}
						onclick={() => onAdd(movie)}
						>{selectedIds.includes(movie.id) ? 'Added' : 'Add'}</button
					>
				</li>
			{/each}
		</ul>
	{/if}
</section>

<style lang="scss">
	.film-search {
		h2 {
			margin-bottom: var(--space-8);
		}

		form {
			margin-bottom: var(--space-8);
		}

		label {
			display: block;
			margin-bottom: var(--space-2);
			font-weight: var(--weight-semibold);
		}
	}

	.search-fields {
		flex-wrap: wrap;
		display: flex;
		gap: var(--space-2);

		input {
			flex: 1 1 12rem;
			min-width: 0;
		}

		button {
			display: inline-flex;
			align-items: center;
			gap: var(--space-2);
		}
	}

	.results {
		list-style: none;

		li {
			display: flex;
			align-items: center;
			gap: var(--space-4);
			padding: var(--space-4) 0;
			border-top: var(--border-width) solid var(--border);
		}

		img,
		.poster-placeholder {
			width: var(--poster-thumbnail-width);
			aspect-ratio: 2 / 3;
			flex: none;
			object-fit: cover;
			background: var(--surface);
		}

		button {
			min-width: var(--control-size);
			min-height: var(--control-size);
			padding: var(--space-1) 0;
			border: 0;
			border-bottom: var(--border-width) solid currentColor;
			background: none;
			color: var(--foreground);
			font: inherit;
			cursor: pointer;

			&:disabled {
				border-bottom-color: transparent;
				color: var(--muted-foreground);
				cursor: not-allowed;
			}
		}
	}

	.film-info {
		min-width: 0;
		flex: 1 1 12rem;

		h3 {
			font-size: var(--text-title);
			overflow-wrap: anywhere;
		}

		p {
			margin-top: var(--space-1);
			color: var(--muted-foreground);
			font-size: var(--text-small);
		}
	}

	.message,
	.empty {
		margin: var(--space-4) 0;
		color: var(--muted-foreground);
	}
</style>
