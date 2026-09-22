import { apiHandler } from '$lib/server/api';
import { cacheTtl, jsonResponse, tmdbGet } from '$lib/server/tmdb';
import * as validate from '$lib/server/validation';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals, params, url }) =>
	apiHandler(async () => {
		const mediaType = validate.mediaType(params.mediaType);
		const id = validate.mediaId(params.id);
		const region = validate.region(url.searchParams.get('region'));
		const result = await tmdbGet(
			`/${mediaType}/${id}/watch/providers`,
			new URLSearchParams(),
			`providers:${mediaType}:${id}`,
			cacheTtl.details,
			locals.requestId
		);
		if (!region) return jsonResponse(result);
		return jsonResponse(filterRegion(result, region));
	});

function filterRegion(value: unknown, region: string): unknown {
	if (!value || typeof value !== 'object') return value;

	const response = value as { id?: unknown; results?: unknown };
	const results = response.results;
	if (!results || typeof results !== 'object') return { id: response.id, results: {} };

	const match = (results as Record<string, unknown>)[region];
	return { id: response.id, results: match === undefined ? {} : { [region]: match } };
}
