<script lang="ts">
	import Nav from './nav.svelte';

	let { children } = $props();
</script>

<Nav />
<main class="site-layout">
	{@render children()}
</main>
