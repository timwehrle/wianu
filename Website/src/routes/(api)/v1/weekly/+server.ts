import { apiHandler, ApiError } from '#lib/server/api.js';
import { isAdmin } from '#lib/server/admin-auth.js';
import { readWeekly, publishWeekly } from '#lib/server/weekly.js';
import { jsonResponse } from '#lib/server/tmdb.js';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = () =>
	apiHandler(async () => jsonResponse(await readWeekly()));

export const PUT: RequestHandler = ({ cookies, locals, request, url }) =>
	apiHandler(async () => {
		if (!isAdmin(cookies)) {
			throw new ApiError(401, 'unauthorized', 'Admin sign in required.');
		}

		if (request.headers.get('origin') !== url.origin) {
			throw new ApiError(
				403,
				'invalid_origin',
				'Request origin is not allowed.'
			);
		}

		if (!request.headers.get('content-type')?.startsWith('application/json')) {
			throw new ApiError(415, 'unsupported_media_type', 'Expected JSON.');
		}

		let body: unknown;

		try {
			body = await request.json();
		} catch {
			throw new ApiError(400, 'invalid_json', 'Invalid JSON body.');
		}

		return jsonResponse(
			await publishWeekly(
				(body as { movieIds?: unknown })?.movieIds,
				(body as { reasons?: unknown })?.reasons,
				locals.requestId
			)
		);
	});
