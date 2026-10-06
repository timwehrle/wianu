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
									size={24}
									strokeWidth={1}
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
		gap: 0 clamp(1.5rem, 4vw, 4rem);
		list-style: none;

		@include at-least(medium) {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	.weekly-list-film {
		position: relative;
		display: grid;
		grid-template-columns: repeat(6, minmax(0, 1fr));
		column-gap: clamp(0.5rem, 1.5vw, 1rem);
		row-gap: 1.5rem;
		align-content: start;
		min-width: 0;
		padding-block: clamp(2rem, 4vw, 4rem);
		border-top: 1px solid var(--weekly-border);
	}

	.weekly-list-number {
		position: absolute;
		z-index: 2;
		top: clamp(2rem, 4vw, 4rem);
		left: 0;
		color: var(--weekly-muted);
		font-family: var(--font-serif);
		font-size: clamp(6rem, 18vw, 12rem);
		line-height: 0.75;
		pointer-events: none;
	}

	.weekly-list-art {
		position: relative;
		grid-column: 2 / 7;
		aspect-ratio: 16 / 10;
		min-width: 0;
		margin-top: 1rem;
		background: var(--weekly-image-placeholder);

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
			font-size: clamp(2.5rem, 5vw, 4.5rem);
			line-height: 1;
			letter-spacing: -0.025em;
			overflow-wrap: anywhere;
		}
	}

	.weekly-list-film-link {
		color: inherit;
		text-decoration: none;

		&:hover {
			text-decoration: underline;
			text-decoration-thickness: 1px;
			text-underline-offset: 0.12em;
		}

		&:focus-visible {
			outline: 2px solid var(--accent);
			outline-offset: 5px;
		}
	}

	.weekly-list-link-icon {
		display: inline-flex;
		margin-left: 0.25rem;
		color: var(--accent);
		vertical-align: baseline;
	}

	.weekly-list-year {
		margin-top: 0.5rem;
		color: var(--weekly-quiet);
		font-family: var(--font-serif);
		font-size: clamp(1.5rem, 2.5vw, 2rem);
		line-height: 1;
	}

	.weekly-list-reason {
		grid-column: 2 / 7;
		min-width: 0;
	}

	.weekly-list-reason-label {
		margin-bottom: 0.75rem;
		font-size: 1rem;
		font-weight: 650;
	}

	.weekly-list-reason-text {
		max-width: 36ch;
		font-family: var(--font-serif);
		font-size: clamp(1.75rem, 2.5vw, 2.75rem);
		line-height: 1.25;
		overflow-wrap: anywhere;
	}

	.weekly-list-featured {
		grid-column: 1 / -1;
		row-gap: clamp(2rem, 4vw, 4rem);
		padding-block: clamp(3rem, 6vw, 6rem);

		.weekly-list-number {
			top: clamp(3rem, 6vw, 6rem);
			color: var(--accent);
			font-size: clamp(7rem, 25vw, 22rem);
		}

		.weekly-list-art {
			margin-top: 1.5rem;

			&.poster-fallback {
				max-width: 26rem;
			}
		}

		.weekly-list-heading h3 {
			font-size: clamp(3rem, 8vw, 8rem);
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
