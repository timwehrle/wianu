<script lang="ts">
	import '../../styles/index.css';
	import SiteLayout from './_components/site-layout.svelte';

	let { children } = $props();
</script>

<SiteLayout>
	{@render children()}
</SiteLayout>
