<script lang="ts">
	import SiteNav from './SiteNav.svelte';
	import SiteFooter from './SiteFooter.svelte';

	let { children } = $props();
</script>

<div class="site-shell">
	<SiteNav />
	<main class="site-layout">
		{@render children()}
	</main>
	<SiteFooter />
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
