<script lang="ts">
	import { resolve } from '$app/paths';
	import TextLink from '$lib/components/text-link.svelte';
	import type { WeeklyMovie, WeeklySelectionMovie } from '$lib/server/weekly';
	import { untrack } from 'svelte';
	import type { ActionData, PageData } from './$types';
	import FilmSearch from './_components/film-search.svelte';
	import SelectedFilms from './_components/selected-films.svelte';
	import WeeklyLogin from './_components/weekly-login.svelte';

	let { data, form }: { data: PageData; form: ActionData } = $props();
	let selected = $state<WeeklySelectionMovie[]>(
		untrack(() =>
			data.movies.map((movie) => ({
				...movie,
				reason: data.selection?.reasons[movie.id] ?? ''
			}))
		)
	);

	function addFilm(movie: WeeklyMovie) {
		if (selected.length < 5 && !selected.some((item) => item.id === movie.id)) {
			selected = [...selected, { ...movie, reason: '' }];
		}
	}

	function moveFilm(index: number, direction: number) {
		const target = index + direction;
		if (target < 0 || target >= selected.length) {
			return;
		}
		const next = [...selected];
		[next[index], next[target]] = [next[target], next[index]];
		selected = next;
	}

	function removeFilm(id: number) {
		selected = selected.filter((movie) => movie.id !== id);
	}

	function updateReason(id: number, reason: string) {
		selected = selected.map((movie) =>
			movie.id === id ? { ...movie, reason } : movie
		);
	}
</script>

<svelte:head>
	<title>Weekly editor — Wianu</title>
	<meta
		name="robots"
		content="noindex, nofollow"
	/>
</svelte:head>

<section class="weekly-admin">
	{#if data.authenticated}
		<form
			method="POST"
			action="?/logout"
		>
			<button
				class="sign-out"
				type="submit">Sign out</button
			>
		</form>
	{/if}
	<header class="page-header">
		<div>
			<h1>Wianu <em>Weekly</em></h1>
		</div>
	</header>

	{#if !data.authenticated}
		<WeeklyLogin message={form?.message} />
	{:else}
		<div class="editor-grid">
			<div class="search-column">
				<FilmSearch
					selectedIds={selected.map((movie) => movie.id)}
					atLimit={selected.length === 5}
					onAdd={addFilm}
				/>
			</div>
			<div class="selection-column">
				<SelectedFilms
					{selected}
					selection={data.selection}
					message={form?.message}
					onMove={moveFilm}
					onRemove={removeFilm}
					onReasonChange={updateReason}
				/>
			</div>
		</div>

		<footer class="page-footer">
			<div class="public-link">
				<TextLink
					href={resolve('/weekly')}
					target="_blank"
					rel="noopener noreferrer">View Weekly</TextLink
				>
			</div>
			{#if data.archive.length > 1}
				<div class="archive">
					<h2>Previous issues</h2>
					<ul>
						{#each data.archive.slice(1) as entry (entry.week)}
							<li>
								<TextLink
									href={resolve(`/weekly?week=${entry.week}`)}
									target="_blank"
									rel="noopener noreferrer"
								>
									{entry.week}
								</TextLink>
							</li>
						{/each}
					</ul>
				</div>
			{/if}
		</footer>
	{/if}
</section>

<style lang="scss">
	.weekly-admin {
		max-width: 1440px;
		margin-inline: auto;
		padding: 7rem 1rem 5rem;
		color: var(--foreground);

		@media (min-width: 850px) {
			padding: 8rem 2rem 6rem;
		}
	}

	.page-header {
		padding-block: 1rem;

		h1 {
			font-family: var(--font-serif);
			font-size: clamp(4rem, 10vw, 9rem);
			font-weight: 400;
		}

		p {
			margin-top: 2rem;
			color: var(--muted-foreground);
		}
	}

	.sign-out {
		padding: 0.5rem 0;
		border: 0;
		border-bottom: 1px solid currentColor;
		background: none;
		color: var(--foreground);
		font: inherit;
		white-space: nowrap;
		cursor: pointer;
	}

	.editor-grid {
		display: grid;
		gap: 3rem;
		border-top: 1px solid var(--border);

		@media (min-width: 850px) {
			grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
			gap: 0;
		}
	}

	.search-column,
	.selection-column {
		min-width: 0;
		padding-top: 2rem;
	}

	.selection-column {
		border-top: 1px solid var(--border);

		@media (min-width: 850px) {
			padding-left: clamp(2rem, 5vw, 5rem);
			border-top: 0;
			border-left: 1px solid var(--border);
		}
	}

	.search-column {
		@media (min-width: 850px) {
			padding-right: clamp(2rem, 5vw, 5rem);
		}
	}

	.page-footer {
		display: grid;
		gap: 3rem;
		margin-top: 5rem;
		padding-top: 1.5rem;
		border-top: 1px solid var(--foreground);
	}

	.public-link {
		justify-self: start;
	}

	.archive {
		h2 {
			margin-bottom: 1rem;
			font-family: var(--font-serif);
			font-size: 2.5rem;
			font-weight: 400;
		}

		ul {
			display: flex;
			flex-wrap: wrap;
			gap: 1rem 2rem;
			list-style: none;
		}
	}
</style>
