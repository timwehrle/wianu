<script lang="ts">
	import HomeHero from './HomeHero.svelte';
	import WeeklyPreview from './WeeklyPreview.svelte';

	let { data } = $props();
</script>

<svelte:head>
	<title>Wianu - All your streaming. One home.</title>
</svelte:head>

<HomeHero />

<WeeklyPreview movies={data.movies} />
