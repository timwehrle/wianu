<script lang="ts">
	import { resolve } from '$app/paths';

	const year = new Date().getFullYear();
</script>

<footer class="footer">
	<div class="footer-content">
		<div class="footer-main">
			<div>
				<a
					class="footer-brand"
					href={resolve('/')}>Wianu</a
				>
				<p>All your streaming. One home.</p>
			</div>
			<nav aria-label="Footer navigation">
				<a href={resolve('/weekly')}>Weekly</a>
				<a
					href={resolve('/download')}
					data-sveltekit-reload>Download for macOS</a
				>
			</nav>
		</div>
		<div class="footer-bottom">
			<p>© {year} Wianu</p>
		</div>
	</div>
</footer>

<style>
	.footer {
		padding: 3rem 1rem 1.5rem;
		background: var(--background);
		color: var(--foreground);
	}

	.footer-content {
		max-width: 1100px;
		margin: 0 auto;
	}

	.footer-main {
		display: flex;
		flex-direction: column;
		gap: 2rem;
		padding-bottom: 3rem;
	}

	.footer-brand {
		font-family: var(--font-serif);
		font-size: clamp(2.5rem, 6vw, 4rem);
		line-height: 1;
		text-decoration: none;
	}

	.footer-main p {
		margin-top: 0.75rem;
	}

	.footer-main nav {
		display: flex;
		flex-wrap: wrap;
		align-items: start;
		gap: 0.75rem 1.5rem;
	}

	.footer a {
		color: inherit;
		text-underline-offset: 0.2em;
	}

	.footer-bottom {
		padding-top: 1.25rem;
		border-top: 1px solid color-mix(in srgb, currentColor 15%, transparent);
		font-size: 0.85rem;
	}

	@media (min-width: 700px) {
		.footer-main {
			flex-direction: row;
			justify-content: space-between;
		}
	}
</style>
