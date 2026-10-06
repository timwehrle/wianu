<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklySelectionMovie } from '#lib/weekly/types.js';
	import TextLink from '#lib/components/TextLink.svelte';
	import WeeklyList from './WeeklyList.svelte';

	let { movies }: { movies: WeeklySelectionMovie[] } = $props();
</script>

{#if movies.length > 0}
	<section
		class="weekly-preview"
		aria-labelledby="weekly-title"
	>
		<div class="weekly-container">
			<header class="weekly-heading">
				<div class="weekly-topline">
					<span>Wianu</span>
					<span>Handpicked each week</span>
				</div>
				<div class="weekly-titleline">
					<h2 id="weekly-title"><em>Weekly</em></h2>
					<span
						class="weekly-mark"
						aria-hidden="true">●</span
					>
				</div>
				<p class="weekly-deck">Five films worth your time.</p>
			</header>

			<WeeklyList {movies} />
			<div class="weekly-link">
				<TextLink href={resolve('weekly')}>Explore this week</TextLink>
			</div>
		</div>
	</section>
{/if}

<style lang="scss">
	.weekly-preview {
		--weekly-border: #242321;
		--weekly-muted: #e8e6e1;
		--weekly-quiet: #716f6a;
		--weekly-image-placeholder: #e5e3df;
		padding-block: clamp(4rem, 8vw, 6rem);
		background-color: var(--background);
	}

	.weekly-container {
		max-width: var(--page-width);
		margin-inline: auto;
		padding-inline: var(--page-gutter);
	}

	.weekly-heading {
		margin-bottom: clamp(3rem, 6vw, 6rem);
	}

	.weekly-topline {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: 1rem;
		padding-top: 0.75rem;
		border-top: 1px solid var(--weekly-border);
		font-family: var(--font-serif);
		font-size: clamp(1.25rem, 2.5vw, 2.5rem);

		> span:last-child {
			text-align: right;
		}
	}

	.weekly-titleline {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: 1rem;
		margin-top: clamp(2rem, 5vw, 5rem);
		padding-bottom: 1rem;
		border-bottom: 1px solid var(--weekly-border);

		h2 {
			font-size: clamp(5rem, 20vw, 18rem);
			line-height: 0.75;
			letter-spacing: -0.025em;
		}
	}

	.weekly-mark {
		color: var(--accent);
		font-size: clamp(1rem, 2vw, 1.5rem);
	}

	.weekly-deck {
		margin-top: clamp(2rem, 4vw, 4rem);
		font-family: var(--font-serif);
		font-size: clamp(2rem, 4vw, 4rem);
		line-height: 1;
	}

	.weekly-link {
		padding-top: 2rem;
		border-top: 1px solid var(--weekly-border);
	}
</style>
