<script lang="ts">
	import Stage from './_components/stage.svelte';
	import WeeklyOverview from './_components/weekly-overview.svelte';

	let { data } = $props();
</script>

<svelte:head>
	<title>Wianu - All your streaming. One home.</title>
</svelte:head>

<Stage />

<WeeklyOverview movies={data.movies} />
