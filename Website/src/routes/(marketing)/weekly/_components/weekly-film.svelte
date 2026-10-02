<script lang="ts">
	import type { WeeklySelectionMovie } from '$lib/server/weekly';
	import { year } from '../utils';

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
		column-gap: 0.5rem;
		row-gap: clamp(1.5rem, 3vw, 3rem);
		padding: 5rem 0;
		border-top: 1px solid var(--weekly-border);
		scroll-margin-top: 5rem;

		@media (min-width: 421px) {
			column-gap: clamp(0.5rem, 2vw, 2rem);
		}

		@media (min-width: 701px) {
			grid-template-columns: repeat(12, minmax(0, 1fr));
			padding: clamp(4rem, 8vw, 9rem) 0;
		}

		&-1 {
			.film-number {
				z-index: 2;
				color: var(--weekly-accent);
			}

			.film-art {
				grid-column: 2 / 7;
				grid-row: 1;

				@media (min-width: 701px) {
					grid-column: 2 / 13;
				}

				&.poster-fallback {
					grid-column: 2 / 6;

					@media (min-width: 701px) {
						grid-column: 3 / 9;
					}
				}
			}

			.film-heading {
				grid-column: 1 / 7;
				grid-row: 2;
				display: block;

				@media (min-width: 421px) {
					display: flex;
					justify-content: space-between;
					align-items: baseline;
					gap: 2rem;
				}

				@media (min-width: 701px) {
					grid-column: 2 / 12;
				}

				> p {
					margin-top: 0.5rem;
					text-align: right;

					@media (min-width: 421px) {
						margin-top: 0;
						text-align: left;
					}
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@media (min-width: 701px) {
					grid-column: 6 / 12;
				}
			}
		}

		&-2 {
			.film-number {
				left: auto;
				right: 0;

				@media (min-width: 701px) {
					top: 2rem;
				}
			}

			.film-art {
				grid-column: 1 / 5;
				grid-row: 2;

				@media (min-width: 701px) {
					grid-column: 1 / 6;
					grid-row: 1 / 4;
					margin-top: 2rem;
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

				@media (min-width: 701px) {
					grid-column: 7 / 13;
					grid-row: 2;
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 4;

				@media (min-width: 701px) {
					grid-column: 7 / 12;
					grid-row: 3;
				}
			}
		}

		&-3 {
			.film-number {
				top: 0.25em;
				font-size: 48vw;

				@media (min-width: 701px) {
					font-size: clamp(12rem, 32vw, 36rem);
				}
			}

			.film-art {
				grid-column: 3 / 7;
				grid-row: 1;
				padding-top: 5rem;

				@media (min-width: 701px) {
					grid-column: 3 / 9;
					grid-row: 1 / 4;
					padding-top: 4rem;
				}

				img {
					object-position: center 42%;
				}
			}

			.film-heading {
				grid-column: 1 / 7;
				grid-row: 2;

				@media (min-width: 701px) {
					grid-column: 9 / 13;
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@media (min-width: 701px) {
					grid-column: 9 / 13;
				}
			}
		}

		&-4 {
			.film-number {
				top: 3rem;
			}

			.film-heading {
				grid-column: 3 / 7;
				grid-row: 1;
				text-align: right;

				@media (min-width: 701px) {
					grid-column: 5 / 13;
				}
			}

			.film-art {
				grid-column: 1 / 6;
				grid-row: 2;

				@media (min-width: 701px) {
					grid-column: 1 / 10;
				}

				img,
				.film-art-placeholder {
					aspect-ratio: 21 / 8;
					object-position: center 45%;
				}

				&.poster-fallback {
					grid-column: 2 / 6;

					@media (min-width: 701px) {
						grid-column: 4 / 9;
					}
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@media (min-width: 701px) {
					grid-column: 8 / 13;
				}
			}
		}

		&-5 {
			.film-number {
				top: 3rem;
				left: auto;
				right: 0;
			}

			.film-art {
				grid-column: 1 / 5;
				grid-row: 1;

				@media (min-width: 701px) {
					grid-column: 2 / 7;
				}
			}

			.film-heading {
				grid-column: 1 / 6;
				grid-row: 2;

				@media (min-width: 701px) {
					grid-column: 2 / 7;
				}

				h3 {
					font-size: clamp(3.25rem, 5vw, 5rem);
				}
			}

			.film-body {
				grid-column: 2 / 7;
				grid-row: 3;

				@media (min-width: 701px) {
					grid-column: 8 / 13;
					grid-row: 2;
				}
			}
		}
	}

	.film-number {
		position: absolute;
		top: 4rem;
		left: 0;
		z-index: 0;
		color: var(--weekly-muted);
		font-family: var(--font-serif);
		font-size: clamp(7rem, 34vw, 14rem);
		font-weight: 400;
		line-height: 0.75;
		pointer-events: none;

		@media (min-width: 701px) {
			top: clamp(3rem, 6vw, 7rem);
			font-size: clamp(9rem, 22vw, 25rem);
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
			background: var(--weekly-image-placeholder);
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
			font-family: var(--font-serif);
			font-size: 12vw;
			font-weight: 400;
			line-height: 1;
			letter-spacing: -1px;
			overflow-wrap: anywhere;

			@media (min-width: 421px) {
				font-size: clamp(3.5rem, 11vw, 5.5rem);
			}

			@media (min-width: 701px) {
				font-size: clamp(3.5rem, 7.5vw, 8rem);
			}
		}

		> p {
			color: var(--weekly-quiet);
			font-family: var(--font-serif);
			font-size: clamp(1.5rem, 2.5vw, 2.5rem);
			line-height: 1;
		}
	}

	.film-body {
		position: relative;
		z-index: 1;
		min-width: 0;
	}

	.film-reason {
		&-label {
			margin-bottom: 0.75rem;
			font-size: 1rem;
			font-weight: 650;
		}

		> p:last-child {
			font-family: var(--font-serif);
			font-size: clamp(1.75rem, 2.5vw, 2.75rem);
			line-height: 1.25;
		}
	}

	.film-overview {
		max-width: 58ch;
		margin-top: 2rem;
		color: var(--weekly-overview);
		font-size: 1rem;
		line-height: 1.75;
	}
</style>
