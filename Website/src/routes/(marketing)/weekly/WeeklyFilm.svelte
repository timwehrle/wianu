<script lang="ts">
	import type { WeeklySelectionMovie } from '#lib/weekly/types.js';
	import { year } from './utils';

	let { movie, index }: { movie: WeeklySelectionMovie; index: number } =
		$props();
</script>

<li
	id={`movie-${movie.id}`}
	class={`film film-${index + 1}`}
>
	<span
		class="film-number"
		aria-hidden="true">{String(index + 1).padStart(2, '0')}</span
	>
	<div
		class="film-art"
		class:poster-fallback={!movie.backdropPath}
	>
		{#if movie.backdropPath}
			<img
				src={`https://image.tmdb.org/t/p/w1280${movie.backdropPath}`}
				alt={`Still from ${movie.title}`}
				loading={index === 0 ? 'eager' : 'lazy'}
			/>
		{:else if movie.posterPath}
			<img
				src={`https://image.tmdb.org/t/p/w780${movie.posterPath}`}
				alt={`Poster for ${movie.title}`}
				loading={index === 0 ? 'eager' : 'lazy'}
			/>
		{:else}
			<div
				class="film-art-placeholder"
				aria-hidden="true"
			></div>
		{/if}
	</div>
	<div class="film-heading">
		<h3>{movie.title}</h3>
		{#if movie.releaseDate}<p>{year(movie.releaseDate)}</p>{/if}
	</div>
	<div class="film-body">
		{#if movie.reason}
			<div class="film-reason">
				<p class="film-reason-label">
					{index === 0 ? 'Why this one' : 'My choice'}
				</p>
				<p>{movie.reason}</p>
			</div>
		{/if}
		{#if movie.overview}<p class="film-overview">
				{movie.overview}
			</p>{/if}
	</div>
</li>

<style lang="scss">
	.film {
		position: relative;
		display: grid;
		grid-template-columns: repeat(6, minmax(0, 1fr));
		column-gap: var(--grid-gap);
		row-gap: var(--space-fluid-sm);
		padding: var(--space-20) 0;
		border-top: var(--border-width) solid var(--border-strong);
		scroll-margin-top: var(--space-20);

		@include at-least(medium) {
			grid-template-columns: repeat(12, minmax(0, 1fr));
			padding: var(--space-fluid-xl) 0;
		}

		&-1 {
			.film-number {
				z-index: 2;
				color: var(--accent);
			}

			.film-art {
				grid-column: 2 / 7;
				grid-row: 1;

				@include at-least(medium) {
					grid-column: 2 / 13;
				}

				&.poster-fallback {
					grid-column: 2 / 6;

					@include at-least(medium) {
						grid-column: 3 / 9;
					}
				}
			}

			.film-heading {
				grid-column: 1 / 7;
				grid-row: 2;
				display: block;

				@include at-least(small) {
					display: flex;
					justify-content: space-between;
					align-items: baseline;
					gap: var(--space-8);
				}

				@include at-least(medium) {
					grid-column: 2 / 12;
				}

				> p {
					margin-top: var(--space-2);
					text-align: right;

					@include at-least(small) {
						margin-top: 0;
						text-align: left;
					}
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@include at-least(medium) {
					grid-column: 6 / 12;
				}
			}
		}

		&-2 {
			.film-number {
				left: auto;
				right: 0;

				@include at-least(medium) {
					top: 2rem;
				}
			}

			.film-art {
				grid-column: 1 / 5;
				grid-row: 2;

				@include at-least(medium) {
					grid-column: 1 / 6;
					grid-row: 1 / 4;
					margin-top: var(--space-8);
				}

				img,
				.film-art-placeholder {
					aspect-ratio: 4 / 5;
					object-position: 62% center;
				}
			}

			.film-heading {
				grid-column: 2 / 7;
				grid-row: 3;

				@include at-least(medium) {
					grid-column: 7 / 13;
					grid-row: 2;
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 4;

				@include at-least(medium) {
					grid-column: 7 / 12;
					grid-row: 3;
				}
			}
		}

		&-3 {
			.film-number {
				top: 0.25em;
			}

			.film-art {
				grid-column: 3 / 7;
				grid-row: 1;
				padding-top: 26vw;

				@include at-least(medium) {
					grid-column: 3 / 9;
					grid-row: 1 / 4;
					padding-top: min(19vw, 10rem);
				}

				img {
					object-position: center 42%;
				}
			}

			.film-heading {
				grid-column: 1 / 7;
				grid-row: 2;

				@include at-least(medium) {
					grid-column: 9 / 13;
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@include at-least(medium) {
					grid-column: 9 / 13;
				}
			}
		}

		&-4 {
			.film-number {
				top: var(--space-12);
			}

			.film-heading {
				grid-column: 3 / 7;
				grid-row: 1;
				text-align: right;

				@include at-least(medium) {
					grid-column: 5 / 13;
				}
			}

			.film-art {
				grid-column: 1 / 6;
				grid-row: 2;

				@include at-least(medium) {
					grid-column: 1 / 10;
				}

				img,
				.film-art-placeholder {
					aspect-ratio: 21 / 8;
					object-position: center 45%;
				}

				&.poster-fallback {
					grid-column: 2 / 6;

					@include at-least(medium) {
						grid-column: 4 / 9;
					}
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@include at-least(medium) {
					grid-column: 8 / 13;
				}
			}
		}

		&-5 {
			.film-number {
				top: var(--space-12);
				left: auto;
				right: 0;
			}

			.film-art {
				grid-column: 1 / 5;
				grid-row: 1;

				@include at-least(medium) {
					grid-column: 2 / 7;
				}
			}

			.film-heading {
				grid-column: 1 / 6;
				grid-row: 2;

				@include at-least(medium) {
					grid-column: 2 / 7;
				}

				h3 {
					font-size: var(--text-heading-large);
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@include at-least(medium) {
					grid-column: 8 / 13;
					grid-row: 2;
				}
			}
		}
	}

	.film-number {
		position: absolute;
		top: var(--space-16);
		left: 0;
		z-index: 0;
		color: var(--muted);
		font-family: var(--font-serif);
		font-size: var(--text-number);
		font-weight: var(--weight-regular);
		line-height: var(--leading-display);
		pointer-events: none;

		@include at-least(medium) {
			top: var(--space-fluid-lg);
		}
	}

	.film-art {
		position: relative;
		z-index: 1;
		min-width: 0;
		align-self: start;

		img,
		.film-art-placeholder {
			display: block;
			width: 100%;
			aspect-ratio: 16 / 10;
			object-fit: cover;
			background: var(--image-placeholder);
		}

		&.poster-fallback {
			img,
			.film-art-placeholder {
				aspect-ratio: 2 / 3;
			}
		}
	}

	.film-heading {
		position: relative;
		z-index: 1;
		min-width: 0;

		h3 {
			font-size: var(--text-heading-display);
			overflow-wrap: anywhere;
		}

		> p {
			color: var(--muted-foreground);
			font-family: var(--font-serif);
			font-size: var(--text-editorial-meta);
			line-height: var(--leading-heading);
		}
	}

	.film-body {
		position: relative;
		z-index: 1;
		min-width: 0;
	}

	.film-reason {
		&-label {
			margin-bottom: var(--space-3);
			font-size: var(--text-body);
			font-weight: var(--weight-semibold);
		}

		> p:last-child {
			font-family: var(--font-serif);
			font-size: var(--text-editorial);
			line-height: var(--leading-copy);
		}
	}

	.film-overview {
		max-width: 58ch;
		margin-top: var(--space-8);
		color: var(--secondary-foreground);
		font-size: var(--text-body);
		line-height: var(--leading-reading);
	}
</style>
