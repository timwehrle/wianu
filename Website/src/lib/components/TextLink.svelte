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
			size={20}
			strokeWidth={1}
		/>
	</span>
</a>

<style>
	.text-link {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		color: var(--foreground);
		font-weight: 600;
		text-decoration: none;
	}

	.text-link-icon {
		display: grid;
		place-items: center;
		width: 1.75rem;
		height: 1.75rem;
		flex: none;
		background-color: var(--accent);
		color: var(--accent-foreground);
		border-radius: 3px;
	}
</style>
