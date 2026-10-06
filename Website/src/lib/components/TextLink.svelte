<script lang="ts">
	import { ArrowUpRightIcon } from '@lucide/svelte';
	import type { Snippet } from 'svelte';
	import type { HTMLAnchorAttributes } from 'svelte/elements';

	let {
		children,
		class: className,
		...attributes
	}: HTMLAnchorAttributes & { children: Snippet } = $props();
</script>

<a
	{...attributes}
	class={`text-link${className ? ` ${className}` : ''}`}
>
	<span class="text-link-label">{@render children()}</span>
	<span
		class="text-link-icon"
		aria-hidden="true"
	>
		<ArrowUpRightIcon
			size="var(--icon-size)"
			strokeWidth={1.5}
		/>
	</span>
</a>

<style>
	.text-link {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		color: var(--foreground);
		font-size: var(--text-body);
		line-height: var(--leading-copy);
		font-weight: var(--weight-semibold);
		text-decoration: none;
	}

	.text-link-icon {
		display: grid;
		place-items: center;
		width: var(--link-icon-box-size);
		height: var(--link-icon-box-size);
		flex: none;
		background-color: var(--accent);
		color: var(--accent-foreground);
		border-radius: var(--radius-small);
	}
</style>
