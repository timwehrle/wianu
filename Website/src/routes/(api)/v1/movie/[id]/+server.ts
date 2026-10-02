import { apiHandler } from '$lib/server/api';
import { getMovie } from '$lib/server/weekly';
import { jsonResponse } from '$lib/server/tmdb';
import { mediaId } from '$lib/server/validation';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ params, locals }) =>
	apiHandler(async () =>
		jsonResponse(await getMovie(Number(mediaId(params.id)), locals.requestId))
	);
