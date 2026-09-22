import { ApiError } from './api';

const MAX_QUERY_LENGTH = 200;

export function query(value: string | null): string {
	const normalized = value?.trim() ?? '';
	if (!normalized) throw new ApiError(400, 'invalid_query', 'Search query must not be empty.');
	if (normalized.length > MAX_QUERY_LENGTH) {
		throw new ApiError(
			400,
			'invalid_query',
			`Search query must not exceed ${MAX_QUERY_LENGTH} characters.`
		);
	}
	return normalized;
}

export function page(value: string | null): number {
	if (value === null || value === '') return 1;
	if (!/^\d+$/.test(value)) invalidPage();
	const parsed = Number(value);
	if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > 500) invalidPage();
	return parsed;
}

function invalidPage(): never {
	throw new ApiError(400, 'invalid_page', 'Page must be between 1 and 500.');
}

export function language(value: string | null): string | undefined {
	if (value === null || value === '') return undefined;
	if (value.length > 35 || !/^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$/.test(value)) {
		throw new ApiError(400, 'invalid_language', 'Language must be a valid language tag.');
	}
	return value;
}

export function region(value: string | null): string | undefined {
	if (value === null || value === '') return undefined;
	if (!/^[A-Z]{2}$/.test(value)) {
		throw new ApiError(400, 'invalid_region', 'Region must be a two-letter country code.');
	}
	return value;
}

export function mediaType(value: string): 'movie' | 'tv' {
	if (value !== 'movie' && value !== 'tv') {
		throw new ApiError(400, 'invalid_media_type', 'Media type must be movie or tv.');
	}
	return value;
}

export function mediaId(value: string): string {
	if (!/^[1-9]\d*$/.test(value) || !Number.isSafeInteger(Number(value))) {
		throw new ApiError(400, 'invalid_id', 'Media ID must be a positive number.');
	}
	return value;
}
