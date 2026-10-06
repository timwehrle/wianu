<script lang="ts">
	import type { WeeklyEntry } from '#lib/weekly/types.js';
	import { issueNumber } from './utils';

	let { selection }: { selection: WeeklyEntry | null } = $props();
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
		<span>{selection ? issueNumber(selection.week) : '—'}</span>
	</div>
	<p class="issue-deck">
		Five films worth your time,<br />handpicked each week.
	</p>
	<span
		class="issue-mark"
		aria-hidden="true">●</span
	>
</header>

<style lang="scss">
	.issue-cover {
		max-width: var(--content-width);
		margin-inline: auto;
		min-height: 80svh;
		display: flex;
		flex-direction: column;

		@include at-least(medium) {
			min-height: min(55rem, 90svh);
		}
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

	.issue-mark {
		align-self: center;
		margin: auto 0;
		color: var(--accent);
		font-size: var(--text-body-large);
	}
</style>
