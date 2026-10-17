<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklySelectionMovie } from '#lib/weekly/types.js';
	import { ArrowUpRightIcon } from '@lucide/svelte';

	let { movies }: { movies: WeeklySelectionMovie[] } = $props();

	const year = (date: string) => date.slice(0, 4);
</script>

{#if movies.length > 0}
	<ol
		class="weekly-list"
		role="list"
	>
		{#each movies as movie, index (movie.id)}
			<li
				class="weekly-list-film"
				class:weekly-list-featured={index === 0}
			>
				<span
					class="weekly-list-number"
					aria-hidden="true"
				>
					{String(index + 1).padStart(2, '0')}
				</span>
				<div
					class="weekly-list-art"
					class:poster-fallback={!movie.backdropPath && !!movie.posterPath}
				>
					{#if movie.backdropPath}
						<img
							src={resolve('/(api)/images/tmdb/[size]/[file]', {
								size: index === 0 ? 'w1280' : 'w780',
								file: movie.backdropPath.slice(1)
							})}
							alt={`Still from ${movie.title}`}
							loading="lazy"
							width="1280"
							height="800"
						/>
					{:else if movie.posterPath}
						<img
							src={resolve('/(api)/images/tmdb/[size]/[file]', {
								size: 'w500',
								file: movie.posterPath.slice(1)
							})}
							alt={`Poster for ${movie.title}`}
							loading="lazy"
							width="500"
							height="750"
						/>
					{:else}
						<div
							class="weekly-list-art-placeholder"
							aria-hidden="true"
						></div>
					{/if}
				</div>
				<div class="weekly-list-heading">
					<h3>
						<a
							class="weekly-list-film-link"
							href={resolve(`weekly#movie-${movie.id}`)}
						>
							{movie.title}
							<span
								class="weekly-list-link-icon"
								aria-hidden="true"
							>
								<ArrowUpRightIcon
									size="var(--icon-size)"
									strokeWidth={1.5}
								/>
							</span>
						</a>
					</h3>
					{#if movie.releaseDate}
						<p class="weekly-list-year">{year(movie.releaseDate)}</p>
					{/if}
				</div>
				{#if index === 0 && movie.reason}
					<div class="weekly-list-reason">
						<p class="weekly-list-reason-label">Why this one</p>
						<p class="weekly-list-reason-text">{movie.reason}</p>
					</div>
				{/if}
			</li>
		{/each}
	</ol>
{/if}

<style lang="scss">
	.weekly-list {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: var(--space-8) var(--grid-gap);
		padding-bottom: var(--space-fluid-md);
		list-style: none;

		@include at-least(large) {
			grid-template-columns: repeat(4, minmax(0, 1fr));
		}
	}

	.weekly-list-film {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		min-width: 0;
		padding-top: var(--space-5);
		border-top: var(--border-width) solid var(--border);
	}

	.weekly-list-number {
		color: var(--muted-foreground);
		font-size: var(--text-small);
		font-variant-numeric: tabular-nums;
	}

	.weekly-list-art {
		aspect-ratio: 16 / 10;
		min-width: 0;
		overflow: hidden;
		background: var(--image-placeholder);

		img,
		.weekly-list-art-placeholder {
			display: block;
			width: 100%;
			height: 100%;
			object-fit: cover;
		}

		&.poster-fallback img {
			object-position: center 25%;
		}
	}

	.weekly-list-heading {
		min-width: 0;
		h3 {
			font-size: var(--text-title);
		}
	}

	.weekly-list-film-link {
		color: inherit;
		text-decoration: none;

		&:hover {
			text-decoration: underline;
			text-decoration-thickness: var(--border-width);
			text-underline-offset: 0.12em;
		}

		&:focus-visible {
			outline: var(--focus-width) solid var(--accent);
			outline-offset: var(--focus-offset);
		}
	}

	.weekly-list-link-icon {
		display: inline-flex;
		margin-left: var(--space-1);
		color: var(--accent);
		vertical-align: baseline;
	}

	.weekly-list-year {
		margin-top: var(--space-2);
		color: var(--muted-foreground);
		font-size: var(--text-small);
	}

	.weekly-list-reason {
		min-width: 0;
	}
	.weekly-list-reason-label {
		margin-bottom: var(--space-3);
		font-size: var(--text-small);
		font-weight: var(--weight-semibold);
	}
	.weekly-list-reason-text {
		max-width: var(--measure-editorial);
		font-family: var(--font-serif);
		font-size: var(--text-lead);
		line-height: var(--leading-copy);
	}

	.weekly-list-featured {
		grid-column: 1 / -1;
		gap: var(--space-5);
		padding-block: var(--space-6) var(--space-4);
		border-top-color: var(--border-strong);

		.weekly-list-number {
			color: var(--accent-text);
		}
		.weekly-list-heading h3 {
			font-size: var(--text-heading-large);
		}

		@include at-least(medium) {
			display: grid;
			grid-template-columns: repeat(12, minmax(0, 1fr));
			grid-template-rows: auto auto 1fr;
			column-gap: var(--space-fluid-md);
			align-items: start;

			.weekly-list-art {
				grid-column: 1 / 8;
				grid-row: 1 / 4;
			}
			.weekly-list-number {
				grid-column: 8 / 13;
				grid-row: 1;
			}
			.weekly-list-heading {
				grid-column: 8 / 13;
				grid-row: 2;
			}
			.weekly-list-reason {
				grid-column: 8 / 13;
				grid-row: 3;
			}
		}
	}
</style>
