import { env } from '$env/dynamic/private';
import { ApiError } from './api';
import { TtlCache } from './cache';
import type { CacheResult } from './cache';
import { log } from './log';

const TMDB_BASE_URL = 'https://api.themoviedb.org/3';
const MAX_RESPONSE_BYTES = 10 * 1024 * 1024;
const UPSTREAM_TIMEOUT_MS = 8_000;
const cache = new TtlCache<string>(1_000);

export const cacheTtl = {
	search: 2 * 60_000,
	details: 30 * 60_000
} as const;

export async function tmdbGet(
	path: string,
	parameters: URLSearchParams,
	cacheKey: string,
	ttlMilliseconds: number,
	requestId: string
): Promise<unknown> {
	let result: CacheResult<string>;
	try {
		result = await cache.getOrCreate(cacheKey, ttlMilliseconds, () => fetchTmdb(path, parameters));
	} catch (error) {
		log('warn', 'tmdb_failure', {
			request_id: requestId,
			upstream_path: path,
			category: error instanceof ApiError ? error.code : 'unexpected_error'
		});
		throw error;
	}
	log('info', 'tmdb_cache', {
		request_id: requestId,
		upstream_path: path,
		cache_status: result.status
	});
	return JSON.parse(result.value) as unknown;
}

async function fetchTmdb(path: string, parameters: URLSearchParams): Promise<string> {
	const token = env.TMDB_TOKEN?.trim();
	if (!token) {
		throw new ApiError(500, 'internal_error', 'An unexpected server error occurred.');
	}

	const url = new URL(`${TMDB_BASE_URL}${path}`);
	url.search = parameters.toString();
	let response: Response;
	try {
		response = await fetch(url, {
			headers: { accept: 'application/json', authorization: `Bearer ${token}` },
			signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS)
		});
	} catch {
		throw new ApiError(503, 'tmdb_unavailable', 'Movie data is temporarily unavailable.');
	}

	const declaredLength = Number(response.headers.get('content-length'));
	if (Number.isFinite(declaredLength) && declaredLength > MAX_RESPONSE_BYTES) {
		throw new ApiError(503, 'tmdb_unavailable', 'Movie data is temporarily unavailable.');
	}
	let body: string;
	try {
		body = await readLimitedBody(response);
	} catch (error) {
		if (error instanceof ApiError) throw error;
		throw new ApiError(503, 'tmdb_unavailable', 'Movie data is temporarily unavailable.');
	}

	if (!response.ok) throw upstreamError(response.status, response.headers.get('retry-after'));
	try {
		JSON.parse(body);
	} catch {
		throw new ApiError(503, 'tmdb_unavailable', 'Movie data is temporarily unavailable.');
	}
	return body;
}

async function readLimitedBody(response: Response): Promise<string> {
	if (!response.body) return '';
	const reader = response.body.getReader();
	const decoder = new TextDecoder();
	let size = 0;
	let body = '';
	while (true) {
		const { done, value } = await reader.read();
		if (done) return body + decoder.decode();
		size += value.byteLength;
		if (size > MAX_RESPONSE_BYTES) {
			await reader.cancel();
			throw new ApiError(503, 'tmdb_unavailable', 'Movie data is temporarily unavailable.');
		}
		body += decoder.decode(value, { stream: true });
	}
}

function upstreamError(status: number, retryAfterHeader: string | null): ApiError {
	if (status === 404)
		return new ApiError(404, 'not_found', 'The requested movie data was not found.');
	if (status === 429) {
		return new ApiError(
			429,
			'tmdb_rate_limited',
			'Movie data rate limit exceeded. Please try again later.',
			parseRetryAfter(retryAfterHeader)
		);
	}
	if (status >= 500) {
		return new ApiError(503, 'tmdb_unavailable', 'Movie data is temporarily unavailable.');
	}
	return new ApiError(502, 'tmdb_error', 'Movie data could not be retrieved.');
}

function parseRetryAfter(value: string | null): number | undefined {
	if (!value) return undefined;
	if (/^\d+$/.test(value)) return Math.min(Number(value), 86_400);
	const timestamp = Date.parse(value);
	if (!Number.isFinite(timestamp)) return undefined;
	return Math.min(Math.max(Math.ceil((timestamp - Date.now()) / 1000), 0), 86_400);
}

export function jsonResponse(value: unknown): Response {
	return Response.json(value, {
		headers: {
			'cache-control': 'no-store',
			'content-type': 'application/json; charset=utf-8'
		}
	});
}
