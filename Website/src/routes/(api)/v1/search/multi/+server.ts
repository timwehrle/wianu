import { apiHandler } from '$lib/server/api';
import { cacheTtl, jsonResponse, tmdbGet } from '$lib/server/tmdb';
import * as validate from '$lib/server/validation';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals, url }) =>
	apiHandler(async () => {
		const query = validate.query(url.searchParams.get('query'));
		const page = validate.page(url.searchParams.get('page'));
		const language = validate.language(url.searchParams.get('language'));
		const parameters = new URLSearchParams({ query, page: String(page), include_adult: 'false' });

		if (language) parameters.set('language', language);

		return jsonResponse(
			await tmdbGet(
				'/search/multi',
				parameters,
				`search:${parameters.toString()}`,
				cacheTtl.search,
				locals.requestId
			)
		);
	});
