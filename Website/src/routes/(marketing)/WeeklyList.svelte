<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '#lib/components/TextLink.svelte';
	import type { WeeklySelectionMovie } from '#lib/weekly/types.js';
	import { ArrowUpRightIcon } from '@lucide/svelte';

	let { movies }: { movies: WeeklySelectionMovie[] } = $props();

	const year = (date: string) => date.slice(0, 4);
</script>

{#if movies.length > 0}
	{@const featured = movies[0]}
	<ol class="weekly-list">
		<li class="weekly-list-featured-film">
			<div class="weekly-list-featured-art">
				<span
					class="weekly-list-featured-number"
					aria-hidden="true">01</span
				>
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
			</div>
			<div class="weekly-list-featured-copy">
				<h3>{featured.title}</h3>
				{#if featured.releaseDate}
					<p class="weekly-list-year">{year(featured.releaseDate)}</p>
				{/if}
				{#if featured.reason}
					<p class="weekly-list-reason">{featured.reason}</p>
				{/if}

				<TextLink href={resolve(`weekly#movie-${featured.id}`)}
					>About the film</TextLink
				>
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
							src={`https://image.tmdb.org/t/p/w500${movie.posterPath}`}
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
					href={resolve(`weekly#movie-${movie.id}`)}
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
		gap: clamp(2rem, 4vw, 4rem);
		align-items: center;
		padding-top: clamp(2rem, 5vw, 5rem);
		border-top: 1px solid var(--surface-border);

		@include at-least(large) {
			grid-template-columns: 22rem minmax(0, 1fr);
			gap: clamp(3rem, 6vw, 6rem);
		}
	}

	.weekly-list-featured-art {
		display: flex;
		align-items: start;
		gap: 1rem;
	}

	.weekly-list-featured-number {
		color: var(--accent);
		font-family: var(--font-serif);
		font-size: clamp(4rem, 7vw, 6rem);
		line-height: 0.85;
	}

	.weekly-list-featured-poster {
		width: 100%;
		max-width: 200px;
		min-width: 0;
		flex: 1;
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
		font-size: clamp(3rem, 5vw, 5rem);
		font-weight: 400;
		margin-bottom: 0.5rem;
		overflow-wrap: anywhere;
	}

	.weekly-list-year {
		color: var(--surface-foreground-muted);
		font-size: 0.75rem;
	}

	.weekly-list-reason {
		max-width: 36ch;
		margin: 2rem 0;
		font-family: var(--font-serif);
		font-size: clamp(1.75rem, 2.5vw, 2.25rem);
		line-height: 1.25;
		display: -webkit-box;
		-webkit-box-orient: vertical;
		-webkit-line-clamp: 4;
		line-clamp: 4;
		overflow: hidden;
	}

	.weekly-list-film-row {
		display: grid;
		grid-template-columns: 3rem 4rem minmax(0, 1fr) 2.75rem;
		gap: 0.5rem;
		align-items: center;
		padding: clamp(1.5rem, 3vw, 3rem) 0;
		border-top: 1px solid var(--surface-border);

		@include at-least(small) {
			grid-template-columns: 4rem 5.5rem minmax(0, 1fr) 2.75rem;
			gap: 0.75rem;
		}

		@include at-least(medium) {
			grid-template-columns: 6.5rem 7rem minmax(0, 1fr) 2.75rem;
		}
	}

	.weekly-list-featured-film + .weekly-list-film-row {
		margin-top: clamp(4rem, 8vw, 8rem);
	}

	.weekly-list-number {
		color: color-mix(in srgb, var(--foreground) 22%, transparent);
		font-family: var(--font-serif);
		font-size: clamp(2.75rem, 6vw, 6rem);
		line-height: 0.85;
		align-self: start;
	}

	.weekly-list-row-poster {
		width: 4rem;
		aspect-ratio: 2 / 3;

		@include at-least(small) {
			width: 5.5rem;
		}

		@include at-least(medium) {
			width: 7rem;
		}

		@include at-least(large) {
			position: relative;
			z-index: 1;
			transform: translateX(-1.5rem);
		}
	}

	.weekly-list-row-copy {
		min-width: 0;
	}

	.weekly-list-row-copy h3 {
		font-family: var(--font-serif);
		font-size: clamp(1.75rem, 4.5vw, 2.5rem);
		font-weight: 400;
		line-height: 1;
		margin-bottom: 0.25rem;
		overflow-wrap: anywhere;
	}

	.weekly-list-row-link {
		display: grid;
		place-items: center;
		width: 2.75rem;
		height: 2.75rem;
		text-decoration: none;
		color: var(--accent);
	}
</style>
