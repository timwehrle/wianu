import { apiHandler } from '$lib/server/api';
import { cacheTtl, jsonResponse, tmdbGet } from '$lib/server/tmdb';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals }) =>
	apiHandler(async () =>
		jsonResponse(
			await tmdbGet(
				'/watch/providers/regions',
				new URLSearchParams(),
				'provider-regions',
				cacheTtl.details,
				locals.requestId
			)
		)
	);
