<script lang="ts">
	import type { WeeklyEntry, WeeklySelectionMovie } from '#lib/weekly/types.js';
	import { ArrowDownIcon, ArrowUpIcon, XIcon } from '@lucide/svelte';

	let {
		selected,
		selection,
		message,
		onMove,
		onRemove,
		onReasonChange
	}: {
		selected: WeeklySelectionMovie[];
		selection: WeeklyEntry | null;
		message?: string;
		onMove: (index: number, direction: number) => void;
		onRemove: (id: number) => void;
		onReasonChange: (id: number, reason: string) => void;
	} = $props();
</script>

<section
	class="selected-films"
	aria-labelledby="selected-films-title"
>
	<div class="selection-heading">
		<div>
			<h2
				class="admin-heading"
				id="selected-films-title"
			>
				The five films
			</h2>
			{#if selection}<p>Latest issue: {selection.week}</p>{/if}
		</div>
		<span>{selected.length} of 5</span>
	</div>

	<form
		method="POST"
		action="?/save"
	>
		<ol>
			{#each selected as movie, index (movie.id)}
				<li>
					<input
						type="hidden"
						name="movieId"
						value={movie.id}
					/>
					<div class="film-heading">
						<span
							class="position"
							aria-hidden="true">{String(index + 1).padStart(2, '0')}</span
						>
						<div class="film-title">
							<h3>{movie.title}</h3>
							{#if movie.releaseDate}<p>{movie.releaseDate.slice(0, 4)}</p>{/if}
						</div>
						<div class="controls">
							<button
								type="button"
								aria-label={`Move ${movie.title} up`}
								disabled={index === 0}
								onclick={() => onMove(index, -1)}
							>
								<ArrowUpIcon
									size={20}
									strokeWidth={1.5}
									aria-hidden="true"
								/>
							</button>
							<button
								type="button"
								aria-label={`Move ${movie.title} down`}
								disabled={index === selected.length - 1}
								onclick={() => onMove(index, 1)}
							>
								<ArrowDownIcon
									size={20}
									strokeWidth={1.5}
									aria-hidden="true"
								/>
							</button>
							<button
								type="button"
								aria-label={`Remove ${movie.title}`}
								onclick={() => onRemove(movie.id)}
							>
								<XIcon
									size={20}
									strokeWidth={1.5}
									aria-hidden="true"
								/>
							</button>
						</div>
					</div>
					<div class="reason-field">
						<label for={`reason-${movie.id}`}
							>Why did you pick {movie.title}?</label
						>
						<textarea
							class="admin-field"
							id={`reason-${movie.id}`}
							name="reason"
							value={movie.reason}
							oninput={(event) =>
								onReasonChange(movie.id, event.currentTarget.value)}
							maxlength="500"
							required
							rows="3"></textarea>
					</div>
				</li>
			{/each}
		</ol>
		{#if selected.length === 0}<p class="empty">
				Search for films to start this week's selection.
			</p>{/if}
		<button
			class="publish admin-action"
			type="submit"
			disabled={selected.length !== 5 ||
				selected.some((movie) => !movie.reason.trim())}
			>Publish five films
		</button>
		{#if message}
			<p
				class="message"
				role="status"
			>
				{message}
			</p>
		{/if}
	</form>
</section>

<style lang="scss">
	.selection-heading {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 2rem;

		p,
		span {
			color: var(--muted-foreground);
		}
	}

	ol {
		list-style: none;

		li {
			padding: 1.5rem 0 2rem;
			border-top: 1px solid var(--border);
		}
	}

	.film-heading {
		display: grid;
		grid-template-columns: 3rem minmax(0, 1fr) auto;
		align-items: start;
		gap: 0.75rem;
	}

	.position {
		color: var(--muted-foreground);
		font-family: var(--font-serif);
		font-size: 2.5rem;
		line-height: 1;
	}

	.film-title {
		min-width: 0;

		h3 {
			font-family: var(--font-serif);
			font-size: clamp(1.75rem, 4vw, 2.5rem);
			font-weight: 400;
			line-height: 1;
			overflow-wrap: anywhere;
		}

		p {
			margin-top: 0.25rem;
			color: var(--muted-foreground);
		}
	}

	.controls {
		display: flex;
		gap: 0.25rem;

		button {
			display: grid;
			place-items: center;
			width: 2rem;
			height: 2rem;
			padding: 0;
			border: 0;
			background: none;
			color: var(--foreground);
			cursor: pointer;

			&:disabled {
				color: var(--muted-foreground);
				cursor: not-allowed;
			}
		}
	}

	.reason-field {
		display: grid;
		gap: 0.5rem;
		margin-top: 1.5rem;
		margin-left: 3.75rem;

		label {
			font-weight: 600;
		}

		textarea {
			width: 100%;
			min-width: 0;
			resize: vertical;
		}
	}

	.publish {
		margin-top: 1.5rem;
		padding: 0.75rem 1.5rem;
		background: var(--accent);
		color: var(--accent-foreground);
	}

	.empty,
	.message {
		margin-top: 1rem;
		color: var(--muted-foreground);
	}
</style>
