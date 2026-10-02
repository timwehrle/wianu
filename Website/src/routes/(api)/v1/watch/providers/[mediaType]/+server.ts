import { apiHandler } from '#lib/server/api.js';
import { cacheTtl, jsonResponse, tmdbGet } from '#lib/server/tmdb.js';
import * as validate from '#lib/server/validation.js';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals, params, url }) =>
	apiHandler(async () => {
		const mediaType = validate.mediaType(params.mediaType);
		const language = validate.language(url.searchParams.get('language'));
		const parameters = new URLSearchParams();
		if (language) {
			parameters.set('language', language);
		}
		return jsonResponse(
			await tmdbGet(
				`/watch/providers/${mediaType}`,
				parameters,
				`provider-list:${mediaType}:${language ?? ''}`,
				cacheTtl.details,
				locals.requestId
			)
		);
	});
