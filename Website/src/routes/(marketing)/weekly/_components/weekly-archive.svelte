<script lang="ts">
	import { resolve } from '$app/paths';
	import type { WeeklyEntry } from '#lib/weekly/types.js';
	import { issueNumber } from '../utils';

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
		max-width: var(--page-width);
		margin-inline: auto;
		padding-top: clamp(5rem, 10vw, 10rem);
		border-top: 1px solid var(--weekly-border);

		h3 {
			margin-bottom: 2rem;
			font-family: var(--font-serif);
			font-size: clamp(3.5rem, 8vw, 8rem);
			font-weight: 400;
			line-height: 1;
		}

		ul {
			list-style: none;
		}

		li {
			border-top: 1px solid var(--weekly-rule);

			&:last-child {
				border-bottom: 1px solid var(--weekly-rule);
			}
		}

		a {
			display: flex;
			justify-content: space-between;
			gap: 1rem;
			padding: 1rem 0;
			color: var(--weekly-foreground);
			text-decoration: none;

			&[aria-current='page'] {
				color: var(--weekly-accent);
			}

			&:focus-visible {
				outline: 2px solid var(--weekly-accent);
				outline-offset: 4px;
			}
		}
	}
</style>
