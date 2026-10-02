<script lang="ts">
	import type { WeeklyEntry } from '$lib/server/weekly';
	import { issueNumber } from '../utils';

	let { selection }: { selection: WeeklyEntry | null } = $props();
</script>

<header class="issue-cover">
	<div class="issue-topline">
		<span>Wianu</span>
		<span
			>{selection ? selection.week.slice(0, 4) : new Date().getFullYear()}</span
		>
	</div>
	<div class="issue-titleline">
		<h2 id="weekly-title"><em>Weekly</em></h2>
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
		max-width: 1500px;
		margin-inline: auto;
		min-height: 82svh;
		display: flex;
		flex-direction: column;

		@media (min-width: 701px) {
			min-height: min(880px, 90svh);
		}
	}

	.issue-topline,
	.issue-titleline {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
	}

	.issue-topline {
		padding-top: 0.75rem;
		border-top: 1px solid var(--weekly-border);
		font-family: var(--font-serif);
		font-size: clamp(1.5rem, 2.5vw, 2.5rem);
		font-weight: 400;
	}

	.issue-titleline {
		gap: 0.5rem;
		margin-top: 3rem;
		border-bottom: 1px solid var(--weekly-border);
		font-family: var(--font-serif);

		@media (min-width: 701px) {
			margin-top: clamp(2rem, 6vw, 6rem);
		}

		h2 {
			margin-left: -8px;
			font-size: 22vw;
			font-weight: 400;
			line-height: 0.75;

			@media (min-width: 421px) {
				font-size: clamp(4.25rem, 22vw, 11rem);
			}

			@media (min-width: 701px) {
				font-size: clamp(6rem, 23vw, 25rem);
			}
		}

		> span {
			font-size: 1.75rem;
			line-height: 1;

			@media (min-width: 421px) {
				font-size: clamp(1.75rem, 7vw, 3rem);
			}

			@media (min-width: 701px) {
				font-size: clamp(2.5rem, 6vw, 6rem);
			}
		}
	}

	.issue-deck {
		margin-top: clamp(3rem, 7vw, 7rem);
		font-family: var(--font-serif);
		font-size: clamp(2rem, 7vw, 3.5rem);
		line-height: 1;

		@media (min-width: 701px) {
			font-size: clamp(2rem, 4vw, 4.5rem);
		}
	}

	.issue-mark {
		align-self: center;
		margin: auto 0;
		color: var(--weekly-accent);
		font-size: 1.25rem;
	}
</style>
