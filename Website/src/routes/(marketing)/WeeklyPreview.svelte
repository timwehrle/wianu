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
		<div class="weekly-container page-container">
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
		padding-block: var(--space-fluid-xl);
		background-color: var(--background);
	}

	.weekly-heading {
		margin-bottom: var(--space-fluid-md);
	}

	.weekly-topline {
		flex-wrap: wrap;
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: var(--space-4);
		padding-top: var(--space-3);
		border-top: var(--border-width) solid var(--border-strong);
		font-family: var(--font-serif);
		font-size: var(--text-editorial-meta);

		> span:last-child {
			text-align: right;
		}
	}

	.weekly-titleline {
		flex-wrap: wrap;
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: var(--space-4);
		margin-top: var(--space-fluid-md);
		padding-bottom: var(--space-4);
		border-bottom: var(--border-width) solid var(--border-strong);

		h2 {
			min-width: 0;
			font-size: var(--text-masthead);
			line-height: var(--leading-display);
		}
	}

	.weekly-mark {
		color: var(--accent);
		font-size: var(--text-body-large);
	}

	.weekly-deck {
		margin-top: var(--space-fluid-md);
		font-family: var(--font-serif);
		font-size: var(--text-deck);
		line-height: var(--leading-heading);
	}

	.weekly-link {
		padding-top: var(--space-8);
		border-top: var(--border-width) solid var(--border-strong);
	}
</style>
