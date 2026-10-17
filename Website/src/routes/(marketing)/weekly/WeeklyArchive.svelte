<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklyEntry } from '#lib/weekly/types.js';
	import { issueNumber, issueDate } from './utils';
	import ArchiveArtwork from './ArchiveArtwork.svelte';

	let {
		archive,
		selection
	}: { archive: WeeklyEntry[]; selection: WeeklyEntry | null } = $props();
</script>

<nav
	class="archive"
	aria-label="Weekly archive"
>
	<h3>Previous issues</h3>
	<ul>
		{#each archive as entry (entry.week)}
			<li>
				<a
					href={resolve(`weekly?week=${entry.week}`)}
					aria-current={entry.week === selection?.week ? 'page' : undefined}
				>
					<ArchiveArtwork movieId={entry.movieIds[0]} />
					<span class="archive-copy">
						<span class="archive-title"
							>Issue {issueNumber(entry, archive)}</span
						>
						<span class="archive-date">Week of {issueDate(entry.week)}</span>
					</span>
					<span class="archive-action"
						>{entry.week === selection?.week
							? 'Viewing issue'
							: 'Read issue'}</span
					>
				</a>
			</li>
		{/each}
	</ul>
</nav>

<style lang="scss">
	.archive {
		max-width: var(--content-width);
		margin-inline: auto;
		padding-top: var(--space-section);
		border-top: var(--border-width) solid var(--border-strong);

		h3 {
			margin-bottom: var(--space-8);
			font-size: var(--text-heading-display);
		}

		ul {
			list-style: none;
		}

		li {
			border-top: var(--border-width) solid var(--border);

			&:last-child {
				border-bottom: var(--border-width) solid var(--border);
			}
		}

		a {
			display: grid;
			grid-template-columns: auto minmax(0, 1fr) auto;
			align-items: center;
			gap: var(--space-4);
			padding: var(--space-4) 0;
			color: var(--foreground);
			text-decoration: none;

			&[aria-current='page'] {
				color: var(--accent-text);
			}

			&:focus-visible {
				outline: var(--focus-width) solid var(--accent);
				outline-offset: var(--focus-offset);
			}
		}

		.archive-copy {
			display: flex;
			flex-direction: column;
			gap: var(--space-2);
			min-width: 0;
		}
		.archive-title {
			font-family: var(--font-serif);
			font-size: var(--text-title);
			line-height: var(--leading-heading);
		}
		.archive-date,
		.archive-action {
			font-size: var(--text-small);
			color: var(--muted-foreground);
			line-height: var(--leading-body);
		}
		.archive-action {
			text-align: right;
		}
		a:hover .archive-title {
			text-decoration: underline;
			text-underline-offset: 0.15em;
		}
	}
</style>
