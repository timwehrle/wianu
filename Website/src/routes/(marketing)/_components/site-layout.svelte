<script lang="ts">
	import Nav from './nav.svelte';
	import Footer from './footer.svelte';

	let { children } = $props();
</script>

<div class="site-shell">
	<Nav />
	<main class="site-layout">
		{@render children()}
	</main>
	<Footer />
</div>

<style>
	.site-shell {
		display: flex;
		min-height: 100vh;
		flex-direction: column;
	}

	.site-layout {
		flex: 1;
	}
</style>
