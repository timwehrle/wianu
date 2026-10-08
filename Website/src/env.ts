import { defineEnvVars } from '@sveltejs/kit/env';

export const variables = defineEnvVars({
	WEEKLY_ADMIN_PASSWORD_HASH: { schema: (input) => input?.trim() || undefined },
	WEEKLY_SESSION_SECRET: { schema: (input) => input?.trim() || undefined },
	TMDB_TOKEN: { schema: (input) => input?.trim() || undefined },
	WEEKLY_DATA_FILE: {
		schema: (input) => input?.trim() || '.data/weekly.json'
	}
});
