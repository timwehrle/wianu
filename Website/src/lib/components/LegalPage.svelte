<script lang="ts">
	import type { Snippet } from 'svelte';
	let { title, children }: { title: string; children: Snippet } = $props();
</script>

<div class="page-frame">
	<article class="legal-page">
		<header>
			<h1>{title}</h1>
		</header>
		<div class="legal-copy">{@render children()}</div>
	</article>
</div>

<style lang="scss">
	.legal-page {
		max-width: var(--measure-prose);
		margin-inline: auto;
	}

	header {
		padding-block: var(--space-fluid-md);
		border-bottom: var(--border-width) solid var(--border);
	}

	h1 {
		font-size: var(--text-display);
	}

	.legal-copy {
		padding-top: var(--space-8);
		line-height: var(--leading-reading);
	}

	.legal-copy :global(section + section) {
		margin-top: var(--space-12);
	}

	.legal-copy :global(h2) {
		margin-bottom: var(--space-5);
		font-size: var(--text-title);
	}

	.legal-copy :global(p + p),
	.legal-copy :global(ul) {
		margin-top: var(--space-4);
	}

	.legal-copy :global(ul) {
		padding-left: var(--space-6);
		margin-bottom: var(--space-4);
	}

	.legal-copy :global(address) {
		font-style: normal;
	}

	.legal-copy :global(a) {
		text-underline-offset: 0.2em;
	}
</style>
