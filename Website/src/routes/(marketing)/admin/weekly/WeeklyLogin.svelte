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
		max-width: var(--measure-copy);
		padding-top: var(--space-8);
		border-top: var(--border-width) solid var(--border);

		h2 {
			margin-bottom: var(--space-8);
		}

		form {
			display: grid;
			gap: var(--space-3);
		}

		label {
			font-weight: var(--weight-semibold);
		}

		input {
			width: 100%;
		}

		button {
			justify-self: start;
			margin-top: var(--space-2);
		}
	}

	.message {
		margin-top: var(--space-4);
		color: var(--accent-text);
	}
</style>
