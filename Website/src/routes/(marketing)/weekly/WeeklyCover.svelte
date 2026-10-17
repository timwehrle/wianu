<script lang="ts">
	import type { WeeklyEntry, WeeklySelectionMovie } from '#lib/weekly/types.js';
	import { issueNumber } from './utils';

	let {
		selection,
		archive,
		movies
	}: {
		selection: WeeklyEntry | null;
		archive: WeeklyEntry[];
		movies: WeeklySelectionMovie[];
	} = $props();
</script>

<header class="issue-cover">
	<div class="issue-topline">
		<span>Wianu</span>
		<span>
			{selection ? selection.week.slice(0, 4) : new Date().getFullYear()}
		</span>
	</div>
	<div class="issue-titleline">
		<h1 id="weekly-title"><em>Weekly</em></h1>
		<span>{selection ? issueNumber(selection, archive) : '—'}</span>
	</div>
	<p class="issue-deck">Five films worth your time.</p>
	{#if movies.length > 0}
		<nav
			class="issue-contents"
			aria-label="Films in this issue"
		>
			<ol>
				{#each movies as movie, index (movie.id)}
					<li>
						<a href={`#movie-${movie.id}`}
							><span>{String(index + 1).padStart(2, '0')}</span>{movie.title}</a
						>
					</li>
				{/each}
			</ol>
		</nav>
	{/if}
</header>

<style lang="scss">
	.issue-cover {
		max-width: var(--content-width);
		margin-inline: auto;
		padding-bottom: var(--space-fluid-md);
		display: flex;
		flex-direction: column;
	}

	.issue-topline,
	.issue-titleline {
		flex-wrap: wrap;
		display: flex;
		justify-content: space-between;
		align-items: baseline;
	}

	.issue-topline {
		padding-top: var(--space-3);
		border-top: var(--border-width) solid var(--border-strong);
		font-family: var(--font-serif);
		font-size: var(--text-editorial-meta);
		font-weight: var(--weight-regular);
	}

	.issue-titleline {
		flex-wrap: wrap;
		gap: var(--space-4);
		margin-top: var(--space-fluid-md);
		padding-bottom: var(--space-4);
		border-bottom: var(--border-width) solid var(--border-strong);
		font-family: var(--font-serif);

		h1 {
			min-width: 0;
			font-size: var(--text-masthead);
			line-height: var(--leading-display);
		}

		> span {
			font-size: var(--text-heading);
			line-height: var(--leading-heading);
		}
	}

	.issue-deck {
		margin-top: var(--space-fluid-md);
		font-family: var(--font-serif);
		font-size: var(--text-deck);
		line-height: var(--leading-heading);
	}

	.issue-contents {
		margin-top: var(--space-8);

		ol {
			display: flex;
			flex-wrap: wrap;
			gap: var(--space-2) var(--space-6);
			list-style: none;
		}

		a {
			display: inline-flex;
			align-items: baseline;
			gap: var(--space-2);
			padding-block: var(--space-3);
			color: var(--foreground);
			text-decoration: none;
			text-underline-offset: 0.25em;

			span {
				color: var(--accent-text);
				font-size: var(--text-small);
			}
			&:hover {
				text-decoration: underline;
			}
			&:focus-visible {
				outline: var(--focus-width) solid var(--accent);
				outline-offset: var(--focus-offset);
			}
		}
	}
</style>
