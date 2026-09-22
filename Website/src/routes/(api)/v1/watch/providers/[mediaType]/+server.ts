import { apiHandler } from '$lib/server/api';
import { cacheTtl, jsonResponse, tmdbGet } from '$lib/server/tmdb';
import * as validate from '$lib/server/validation';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals, params, url }) =>
	apiHandler(async () => {
		const mediaType = validate.mediaType(params.mediaType);
		const language = validate.language(url.searchParams.get('language'));
		const parameters = new URLSearchParams();
		if (language) parameters.set('language', language);
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
