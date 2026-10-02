<script lang="ts">
	let { message }: { message?: string } = $props();
</script>

<div class="login">
	<h2 class="admin-heading">Sign in</h2>
	<form
		method="POST"
		action="?/login"
	>
		<label for="password">Password</label>
		<input
			class="admin-field"
			id="password"
			type="password"
			name="password"
			autocomplete="current-password"
			required
		/>
		<button
			class="admin-action"
			type="submit">Sign in</button
		>
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
		}

		button {
			justify-self: start;
			margin-top: 0.5rem;
			padding: 0.75rem 1.5rem;
		}
	}

	.message {
		margin-top: 1rem;
		color: var(--accent);
	}
</style>
