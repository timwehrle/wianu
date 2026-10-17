<script lang="ts">
	import type { Snippet } from 'svelte';
	import type {
		HTMLAnchorAttributes,
		HTMLButtonAttributes
	} from 'svelte/elements';

	type Props = {
		children: Snippet;
		size?: 'default' | 'icon';
		variant?: 'glass' | 'link';
	} & (
		| (HTMLButtonAttributes & { href?: never; element?: HTMLButtonElement })
		| (HTMLAnchorAttributes & {
				href: string;
				element?: HTMLAnchorElement;
				type?: never;
		  })
	);

	let {
		children,
		element = $bindable<HTMLButtonElement | HTMLAnchorElement>(),
		href,
		class: className,
		type = 'button',
		size = 'default',
		variant = 'glass',
		...attributes
	}: Props = $props();
</script>

{#if href !== undefined}
	<a
		bind:this={element}
		{...attributes as HTMLAnchorAttributes}
		{href}
		class={['button', `button-${size}`, `button-${variant}`, className]}
	>
		{@render children()}
	</a>
{:else}
	<button
		bind:this={element}
		{...attributes as HTMLButtonAttributes}
		{type}
		class={['button', `button-${size}`, `button-${variant}`, className]}
	>
		{@render children()}
	</button>
{/if}

<style lang="scss">
	@use '../../styles/glass';

	.button {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		flex-shrink: 0;
		max-width: 100%;
		min-height: var(--control-size);
		padding: var(--space-3) var(--space-5);
		border: 0;
		border-radius: 999px;
		background: transparent;
		color: inherit;
		font: inherit;
		line-height: var(--leading-copy);
		text-align: center;
		text-decoration: none;
		cursor: pointer;
		transition:
			background-color 150ms,
			transform 150ms;

		&:disabled {
			opacity: 0.45;
			cursor: not-allowed;
		}
	}

	.button-glass {
		@include glass.surface(0 6px 18px #00000014);

		&:hover:not(:disabled) {
			background-color: glass.$hover-background;
		}

		&:active:not(:disabled) {
			transform: translateY(1px);
		}
	}

	.button-link {
		min-height: auto;
		padding: 0;
		border-radius: 0;
		text-decoration: underline;
		text-underline-offset: 0.2em;
	}

	.button-icon {
		width: var(--control-size);
		height: var(--control-size);
		padding: 0;
	}

	@media (prefers-reduced-motion: reduce) {
		.button {
			transition: none;
		}
	}
</style>
