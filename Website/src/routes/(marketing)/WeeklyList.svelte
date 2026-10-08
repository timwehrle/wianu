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
				class:has-reason={index === 0 && !!movie.reason}
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
							src={`https://image.tmdb.org/t/p/${index === 0 ? 'w1280' : 'w780'}${movie.backdropPath}`}
							alt={`Still from ${movie.title}`}
							loading="lazy"
							width="1280"
							height="800"
						/>
					{:else if movie.posterPath}
						<img
							src={`https://image.tmdb.org/t/p/w500${movie.posterPath}`}
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
		gap: 0 var(--space-fluid-md);
		list-style: none;

		@include at-least(medium) {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	.weekly-list-film {
		position: relative;
		display: grid;
		grid-template-columns: repeat(6, minmax(0, 1fr));
		column-gap: var(--grid-gap);
		row-gap: var(--space-6);
		align-content: start;
		min-width: 0;
		padding-block: var(--space-fluid-md);
		border-top: var(--border-width) solid var(--border-strong);
	}

	.weekly-list-number {
		position: absolute;
		z-index: 2;
		top: var(--space-fluid-md);
		left: 0;
		color: var(--muted);
		font-family: var(--font-serif);
		font-size: var(--text-number-small);
		line-height: var(--leading-display);
		pointer-events: none;
	}

	.weekly-list-art {
		position: relative;
		grid-column: 2 / 7;
		aspect-ratio: 16 / 10;
		min-width: 0;
		margin-top: var(--space-4);
		background: var(--image-placeholder);

		img,
		.weekly-list-art-placeholder {
			display: block;
			width: 100%;
			height: 100%;
			object-fit: cover;
		}

		&.poster-fallback {
			max-width: 14rem;
			aspect-ratio: 2 / 3;
		}
	}

	.weekly-list-heading {
		position: relative;
		grid-column: 1 / 7;
		min-width: 0;

		h3 {
			font-size: var(--text-heading);
			overflow-wrap: anywhere;
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
		font-family: var(--font-serif);
		font-size: var(--text-editorial-meta);
		line-height: var(--leading-heading);
	}

	.weekly-list-reason {
		grid-column: 2 / 7;
		min-width: 0;
	}

	.weekly-list-reason-label {
		margin-bottom: var(--space-3);
		font-size: var(--text-body);
		font-weight: var(--weight-semibold);
	}

	.weekly-list-reason-text {
		max-width: var(--measure-editorial);
		font-family: var(--font-serif);
		font-size: var(--text-editorial);
		line-height: var(--leading-copy);
		overflow-wrap: anywhere;
	}

	.weekly-list-featured {
		grid-column: 1 / -1;
		row-gap: var(--space-fluid-md);
		padding-block: var(--space-fluid-lg);

		.weekly-list-number {
			top: var(--space-fluid-lg);
			color: var(--accent);
			font-size: var(--text-number);
		}

		.weekly-list-art {
			margin-top: var(--space-6);

			&.poster-fallback {
				max-width: 26rem;
			}
		}

		.weekly-list-heading h3 {
			font-size: var(--text-heading-display);
		}

		@include at-least(medium) {
			grid-template-columns: repeat(12, minmax(0, 1fr));

			.weekly-list-art {
				grid-column: 3 / 13;
			}

			.weekly-list-heading {
				grid-column: 1 / 13;
			}

			&.has-reason .weekly-list-heading {
				grid-column: 1 / 7;
			}

			.weekly-list-reason {
				grid-column: 8 / 13;
				align-self: start;
			}
		}
	}
</style>
