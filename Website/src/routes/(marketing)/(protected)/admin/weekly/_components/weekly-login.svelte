<script lang="ts">
	let { message }: { message?: string } = $props();
</script>

<div class="login">
	<h2>Sign in</h2>
	<form
		method="POST"
		action="?/login"
	>
		<label for="password">Password</label>
		<input
			id="password"
			type="password"
			name="password"
			autocomplete="current-password"
			required
		/>
		<button type="submit">Sign in</button>
	</form>
	{#if message}<p
			class="message"
			role="alert"
		>
			{message}
		</p>{/if}
</div>

<style lang="scss">
	.login {
		max-width: 34rem;
		padding-top: 2rem;
		border-top: 1px solid var(--border);

		h2 {
			margin-bottom: 2rem;
			font-family: var(--font-serif);
			font-size: clamp(2.5rem, 6vw, 4rem);
			font-weight: 400;
		}

		form {
			display: grid;
			gap: 0.75rem;
		}

		label {
			font-weight: 600;
		}

		input {
			width: 100%;
			padding: 0.75rem;
			border: 1px solid var(--border);
			border-radius: 0;
			background: var(--background);
			color: var(--foreground);
			font: inherit;
		}

		button {
			justify-self: start;
			margin-top: 0.5rem;
			padding: 0.75rem 1.5rem;
			border: 0;
			background: var(--foreground);
			color: var(--background);
			font: inherit;
			cursor: pointer;
		}
	}

	.message {
		margin-top: 1rem;
		color: var(--accent);
	}
</style>
