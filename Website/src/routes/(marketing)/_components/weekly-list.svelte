<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '$lib/components/text-link.svelte';
	import type { WeeklySelectionMovie } from '$lib/weekly/types';
	import { ArrowUpRightIcon } from '@lucide/svelte';

	let { movies }: { movies: WeeklySelectionMovie[] } = $props();

	const year = (date: string) => date.slice(0, 4);
</script>

{#if movies.length > 0}
	{@const featured = movies[0]}
	<ol class="weekly-list">
		<li class="weekly-list-featured-film">
			<div class="weekly-list-featured-poster">
				{#if featured.posterPath}
					<img
						src={`https://image.tmdb.org/t/p/w500${featured.posterPath}`}
						alt={`Poster for ${featured.title}`}
						fetchpriority="high"
					/>
				{:else}
					<div
						class="weekly-list-poster-placeholder"
						aria-hidden="true"
					></div>
				{/if}
			</div>
			<div class="weekly-list-featured-copy">
				<p class="weekly-list-eyebrow">01 / Featured film</p>
				<h3>{featured.title}</h3>
				{#if featured.releaseDate}
					<p class="weekly-list-year">{year(featured.releaseDate)}</p>
				{/if}
				{#if featured.reason}
					<p class="weekly-list-reason">{featured.reason}</p>
				{/if}
				<TextLink href={resolve(`/weekly#movie-${featured.id}`)}>
					About the film
				</TextLink>
			</div>
		</li>
		{#each movies.slice(1) as movie, index (movie.id)}
			<li class="weekly-list-film-row">
				<span class="weekly-list-number"
					>{String(index + 2).padStart(2, '0')}</span
				>
				<div class="weekly-list-row-poster">
					{#if movie.posterPath}
						<img
							src={`https://image.tmdb.org/t/p/w154${movie.posterPath}`}
							alt={`Poster for ${movie.title}`}
							loading="lazy"
						/>
					{:else}
						<div
							class="weekly-list-poster-placeholder"
							aria-hidden="true"
						></div>
					{/if}
				</div>
				<div class="weekly-list-row-copy">
					<h3>{movie.title}</h3>
					{#if movie.releaseDate}
						<p class="weekly-list-year">{year(movie.releaseDate)}</p>
					{/if}
				</div>
				<a
					class="weekly-list-row-link"
					href={resolve(`/weekly#movie-${movie.id}`)}
					aria-label={`Read more about ${movie.title}`}
				>
					<ArrowUpRightIcon strokeWidth={1} />
				</a>
			</li>
		{/each}
	</ol>
{/if}

<style lang="scss">
	.weekly-list {
		list-style: none;
	}

	.weekly-list-featured-film {
		display: grid;
		grid-template-columns: 1fr;
		gap: 2rem;
		align-items: center;
		border-radius: 3px;
	}

	.weekly-list-featured-poster {
		width: 100%;
		max-width: 200px;
	}

	.weekly-list-featured-poster img,
	.weekly-list-row-poster img,
	.weekly-list-poster-placeholder {
		width: 100%;
		height: 100%;
		object-fit: cover;
		background: #e5e5e8;
		border-radius: 3px;
	}

	.weekly-list-featured-poster img,
	.weekly-list-featured-poster .weekly-list-poster-placeholder {
		aspect-ratio: 2 / 3;
	}

	.weekly-list-featured-copy h3 {
		font-family: var(--font-serif);
		font-size: 3.25rem;
		font-weight: 400;
		margin: 0.5rem 0;
	}

	.weekly-list-year {
		color: var(--surface-foreground-muted);
		font-size: 0.75rem;
	}

	.weekly-list-reason {
		max-width: 55ch;
		margin: 1.25rem 0;
		display: -webkit-box;
		-webkit-box-orient: vertical;
		-webkit-line-clamp: 4;
		line-clamp: 4;
		overflow: hidden;
	}

	.weekly-list-film-row {
		display: grid;
		grid-template-columns: 2rem 70px minmax(0, 1fr) auto;
		gap: 0.75rem;
		align-items: center;
		padding: 1.5rem 0;
		border-bottom: 1px solid var(--surface-border);

		&:last-child {
			border-bottom: 0;
		}
	}

	.weekly-list-featured-film + .weekly-list-film-row {
		margin-top: 3rem;
		border-top: 1px solid var(--surface-border);
	}

	.weekly-list-number {
		font-family: var(--font-serif);
		font-size: 1.75rem;
		line-height: 1;
		align-self: start;
	}

	.weekly-list-row-poster {
		width: 70px;
		aspect-ratio: 2 / 3;
	}

	.weekly-list-row-copy {
		min-width: 0;
	}

	.weekly-list-row-copy h3 {
		font-family: var(--font-serif);
		font-size: 1.75rem;
		font-weight: 400;
		line-height: 1;
		margin-bottom: 0.25rem;
	}

	.weekly-list-row-link {
		text-decoration: none;
		align-self: start;
		color: inherit;
	}
</style>
