<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklyEntry } from '#lib/weekly/types.js';
	import { issueNumber } from './utils';

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
					<span>{entry.week.slice(0, 4)} / {issueNumber(entry.week)}</span>
					<span
						>{entry.week === selection?.week
							? 'Current issue'
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
			display: flex;
			justify-content: space-between;
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
	}
</style>
