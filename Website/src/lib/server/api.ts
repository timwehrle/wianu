import { json } from '@sveltejs/kit';

export class ApiError extends Error {
	constructor(
		readonly status: number,
		readonly code: string,
		message: string,
		readonly retryAfter?: number
	) {
		super(message);
	}
}

export function errorResponse(error: unknown): Response {
	const apiError =
		error instanceof ApiError
			? error
			: new ApiError(500, 'internal_error', 'An unexpected server error occurred.');

	const headers = new Headers({ 'cache-control': 'no-store' });
	if (apiError.retryAfter !== undefined) headers.set('retry-after', String(apiError.retryAfter));

	return json(
		{ error: { code: apiError.code, message: apiError.message } },
		{ status: apiError.status, headers }
	);
}

export async function apiHandler(operation: () => Promise<Response>): Promise<Response> {
	try {
		return await operation();
	} catch (error) {
		if (!(error instanceof ApiError)) console.error('Unexpected API request failure', error);
		return errorResponse(error);
	}
}
