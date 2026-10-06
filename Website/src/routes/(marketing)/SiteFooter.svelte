<script lang="ts">
	import { resolve } from '$app/paths';

	const year = new Date().getFullYear();
</script>

<footer class="footer">
	<div class="footer-content page-container">
		<div class="footer-main">
			<div>
				<a
					class="footer-brand"
					href={resolve('')}>Wianu</a
				>
				<p>All your streaming. One home.</p>
			</div>
			<nav aria-label="Footer navigation">
				<a href={resolve('the-app')}>App</a>
				<a href={resolve('about')}>About</a>
				<a href={resolve('weekly')}>Weekly</a>
				<a
					href={resolve('download')}
					data-sveltekit-reload>Download for macOS</a
				>
			</nav>
		</div>
		<div class="footer-bottom">
			<p>© {year} Wianu</p>
		</div>
	</div>
</footer>

<style lang="scss">
	.footer {
		padding-block: var(--space-12) var(--space-6);
		background: var(--background);
		color: var(--foreground);
	}

	.footer-main {
		display: flex;
		flex-direction: column;
		gap: var(--space-8);
		padding-bottom: var(--space-12);

		@include at-least(medium) {
			flex-direction: row;
			justify-content: space-between;
		}
	}

	.footer-brand {
		font-family: var(--font-serif);
		font-size: var(--text-heading);
		line-height: var(--leading-heading);
		text-decoration: none;
	}

	.footer-main p {
		margin-top: var(--space-3);
	}

	.footer-main nav {
		display: flex;
		flex-wrap: wrap;
		align-items: start;
		gap: var(--space-3) var(--space-6);
	}

	.footer a {
		color: inherit;
		text-underline-offset: 0.2em;
	}

	.footer-bottom {
		padding-top: var(--space-5);
		border-top: var(--border-width) solid var(--border);
		font-size: var(--text-small);
	}
</style>
