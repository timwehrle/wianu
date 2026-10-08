import { apiHandler } from '#lib/server/api.js';
import { cacheTtl, jsonResponse, tmdbGet } from '#lib/server/tmdb.js';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals }) =>
	apiHandler(async () =>
		jsonResponse(
			await tmdbGet(
				'/configuration',
				new URLSearchParams(),
				'configuration',
				cacheTtl.details,
				locals.requestId
			)
		)
	);
