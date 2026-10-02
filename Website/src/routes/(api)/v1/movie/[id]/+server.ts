import { apiHandler } from '#lib/server/api.js';
import { getMovie } from '#lib/server/weekly.js';
import { jsonResponse } from '#lib/server/tmdb.js';
import { mediaId } from '#lib/server/validation.js';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ params, locals }) =>
	apiHandler(async () =>
		jsonResponse(await getMovie(Number(mediaId(params.id)), locals.requestId))
	);
