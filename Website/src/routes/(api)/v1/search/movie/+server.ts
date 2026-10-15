import { apiHandler } from '#lib/server/api.js';
import { cacheTtl, jsonResponse, tmdbGet } from '#lib/server/tmdb.js';
import * as validate from '#lib/server/validation.js';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals, url }) =>
	apiHandler(async () => {
		const parameters = new URLSearchParams({
			query: validate.query(url.searchParams.get('query')),
			page: String(validate.page(url.searchParams.get('page'))),
			include_adult: 'false'
		});
		const language = validate.language(url.searchParams.get('language'));
		const year = validate.releaseYear(url.searchParams.get('year'));
		if (language) {
			parameters.set('language', language);
		}
		if (year) {
			parameters.set('primary_release_year', year);
		}

		return jsonResponse(
			await tmdbGet(
				'/search/movie',
				parameters,
				`search:movie:${parameters.toString()}`,
				cacheTtl.search,
				locals.requestId
			)
		);
	});
