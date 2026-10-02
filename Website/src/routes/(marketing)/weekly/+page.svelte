<script lang="ts">
	import WeeklyPublication from './_components/weekly-publication.svelte';
	let { data } = $props();
</script>

<svelte:head>
	<title>Wianu Weekly - Five films worth your time</title>
	<meta
		name="description"
		content="Five films picked for Wianu Weekly."
	/>
</svelte:head>

<WeeklyPublication
	movies={data.movies}
	selection={data.selection}
	archive={data.archive}
/>
