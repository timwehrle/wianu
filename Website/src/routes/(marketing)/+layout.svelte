<script lang="ts">
	import '../../styles/index.scss';
	import SiteLayout from './SiteLayout.svelte';

	let { children } = $props();
</script>

<SiteLayout>
	{@render children()}
</SiteLayout>
