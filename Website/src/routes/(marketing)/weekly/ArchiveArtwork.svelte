<script lang="ts">
	import { onMount } from 'svelte';
	import { resolve } from '$app/paths';
	import type { WeeklyMovie } from '#lib/weekly/types.js';

	let { movieId }: { movieId: number | undefined } = $props();
	let element: HTMLSpanElement;
	let image = $state<string | null>(null);

	onMount(() => {
		if (!movieId) {
			return;
		}
		const controller = new AbortController();
		const observer = new IntersectionObserver(
			async (entries) => {
				if (!entries.some((entry) => entry.isIntersecting)) {
					return;
				}
				observer.disconnect();
				try {
					const response = await fetch(resolve(`v1/movie/${movieId}`), {
						signal: controller.signal
					});
					if (!response.ok) {
						return;
					}
					const movie: WeeklyMovie = await response.json();
					const path = movie.backdropPath ?? movie.posterPath;
					if (path) {
						image = resolve('/(api)/images/tmdb/[size]/[file]', {
							size: 'w780',
							file: path.slice(1)
						});
					}
				} catch {
					// Keep the quiet placeholder if artwork is unavailable.
				}
			},
			{ rootMargin: '200px' }
		);
		observer.observe(element);
		return () => {
			observer.disconnect();
			controller.abort();
		};
	});
</script>

<span
	class="artwork"
	bind:this={element}
	aria-hidden="true"
>
	{#if image}<img
			src={image}
			alt=""
			loading="lazy"
		/>{/if}
</span>

<style lang="scss">
	.artwork {
		display: block;
		width: clamp(4rem, 9vw, 7rem);
		aspect-ratio: 16 / 10;
		flex-shrink: 0;
		overflow: hidden;
		background: var(--image-placeholder);
	}
	img {
		display: block;
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
</style>
