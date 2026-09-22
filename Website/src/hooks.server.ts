import { errorResponse, ApiError } from '$lib/server/api';
import { log } from '$lib/server/log';
import { allowRequest } from '$lib/server/rate-limit';
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
	const startedAt = performance.now();
	event.locals.requestId = crypto.randomUUID();
	let response: Response | undefined;

	if (event.url.pathname.startsWith('/v1/')) {
		let client: string | undefined;
		try {
			client = event.getClientAddress();
		} catch {
			log('error', 'client_address_unavailable', { request_id: event.locals.requestId });
			response = errorResponse(
				new ApiError(500, 'internal_error', 'An unexpected server error occurred.')
			);
		}
		if (client && !allowRequest(client)) {
			response = errorResponse(
				new ApiError(429, 'rate_limited', 'Too many requests. Please try again later.', 1)
			);
		}
	}
	response ??= await resolve(event);

	response.headers.set('x-content-type-options', 'nosniff');
	response.headers.set('referrer-policy', 'strict-origin-when-cross-origin');
	response.headers.set('x-request-id', event.locals.requestId);
	log('info', 'http_request', {
		request_id: event.locals.requestId,
		method: event.request.method,
		route: event.route.id ?? 'unmatched',
		status: response.status,
		duration_ms: Math.round(performance.now() - startedAt)
	});
	return response;
};
