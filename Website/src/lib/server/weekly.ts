import { WEEKLY_DATA_FILE } from '$app/env/private';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { ApiError } from './api';
import { cacheTtl, tmdbGet } from './tmdb';
import type {
	WeeklyArchive,
	WeeklyEntry,
	WeeklyMovie
} from '#lib/weekly/types.js';

let pendingWrite: Promise<void> = Promise.resolve();

function dataPath(): string {
	return resolve(WEEKLY_DATA_FILE);
}

export function isoWeek(date: Date): string {
	const day = new Date(
		Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())
	);
	day.setUTCDate(day.getUTCDate() + 4 - (day.getUTCDay() || 7));
	const year = day.getUTCFullYear();
	const yearStart = new Date(Date.UTC(year, 0, 1));
	const number = Math.ceil(
		((day.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7
	);
	return `${year}-W${String(number).padStart(2, '0')}`;
}

function validIds(ids: unknown): ids is number[] {
	return (
		Array.isArray(ids) &&
		ids.length === 5 &&
		ids.every((id) => Number.isSafeInteger(id) && id > 0) &&
		new Set(ids).size === 5
	);
}

function validReason(value: unknown): value is string {
	return (
		typeof value === 'string' &&
		value.trim().length > 0 &&
		value.trim().length <= 500
	);
}

function validStoredReasons(value: unknown, ids: number[]): boolean {
	return (
		value !== null &&
		typeof value === 'object' &&
		!Array.isArray(value) &&
		Object.entries(value).every(
			([id, reason]) => ids.includes(Number(id)) && validReason(reason)
		)
	);
}

function validEntry(value: unknown): value is WeeklyEntry {
	if (!value || typeof value !== 'object') {
		return false;
	}
	const entry = value as Partial<WeeklyEntry>;

	return (
		typeof entry.week === 'string' &&
		/^\d{4}-W(?:0[1-9]|[1-4]\d|5[0-3])$/.test(entry.week) &&
		validIds(entry.movieIds) &&
		(entry.reasons === undefined ||
			validStoredReasons(entry.reasons, entry.movieIds)) &&
		typeof entry.updatedAt === 'string' &&
		!Number.isNaN(Date.parse(entry.updatedAt))
	);
}

function parseArchive(value: unknown): WeeklyArchive {
	if (!value || typeof value !== 'object') {
		throw new Error('Invalid weekly data');
	}
	const data = value as Record<string, unknown>;
	if (Array.isArray(data.weeks)) {
		if (!data.weeks.every(validEntry)) {
			throw new Error('Invalid weekly data');
		}
		const weeks = data.weeks as WeeklyEntry[];
		if (new Set(weeks.map((entry) => entry.week)).size !== weeks.length) {
			throw new Error('Duplicate weekly archive entry');
		}
		return {
			weeks: weeks
				.map((entry) => ({ ...entry, reasons: entry.reasons ?? {} }))
				.sort((a, b) => b.week.localeCompare(a.week))
		};
	}
	// Read the original metadata snapshot. The next publish writes the compact archive format.
	if (Array.isArray(data.movies) && data.movies.length === 0) {
		return { weeks: [] };
	}
	if (
		Array.isArray(data.movies) &&
		validIds(data.movies.map((movie) => movie?.id))
	) {
		const updatedAt =
			typeof data.updatedAt === 'string'
				? data.updatedAt
				: new Date().toISOString();
		const date = new Date(updatedAt);
		if (Number.isNaN(date.getTime())) {
			throw new Error('Invalid weekly date');
		}
		return {
			weeks: [
				{
					week: isoWeek(date),
					movieIds: data.movies.map((movie) => movie.id),
					reasons: {},
					updatedAt
				}
			]
		};
	}
	throw new Error('Invalid weekly data');
}

export async function readWeekly(): Promise<WeeklyArchive> {
	try {
		return parseArchive(JSON.parse(await readFile(dataPath(), 'utf8')));
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
			return { weeks: [] };
		}
		throw error;
	}
}

export async function publishWeekly(
	ids: unknown,
	reasons: unknown,
	requestId: string
): Promise<WeeklyEntry> {
	if (!validIds(ids)) {
		throw new ApiError(
			400,
			'invalid_movies',
			'Select exactly five different movies.'
		);
	}
	if (
		!Array.isArray(reasons) ||
		reasons.length !== ids.length ||
		!reasons.every(validReason)
	) {
		throw new ApiError(
			400,
			'invalid_reasons',
			'Write a reason for each film (up to 500 characters).'
		);
	}
	await Promise.all(ids.map((id) => getMovie(id, requestId)));
	const entry: WeeklyEntry = {
		week: isoWeek(new Date()),
		movieIds: [...ids],
		reasons: Object.fromEntries(
			ids.map((id, index) => [id, reasons[index].trim()])
		),
		updatedAt: new Date().toISOString()
	};
	const write = pendingWrite.then(async () => {
		const archive = await readWeekly();
		archive.weeks = [
			entry,
			...archive.weeks.filter((week) => week.week !== entry.week)
		].sort((a, b) => b.week.localeCompare(a.week));
		const path = dataPath();
		await mkdir(dirname(path), { recursive: true });
		const temporaryPath = `${path}.${randomUUID()}.tmp`;
		await writeFile(temporaryPath, JSON.stringify(archive, null, 2), {
			mode: 0o600
		});
		await rename(temporaryPath, path);
	});
	pendingWrite = write.catch(() => undefined);
	await write;
	return entry;
}

export async function getMovie(
	id: number,
	requestId: string
): Promise<WeeklyMovie> {
	const raw = await tmdbGet(
		`/movie/${id}`,
		new URLSearchParams(),
		`weekly-movie:${id}`,
		cacheTtl.details,
		requestId
	);
	if (!raw || typeof raw !== 'object') {
		throw new ApiError(502, 'tmdb_error', 'Invalid movie data.');
	}
	const movie = raw as Record<string, unknown>;
	if (movie.id !== id || typeof movie.title !== 'string') {
		throw new ApiError(502, 'tmdb_error', 'Invalid movie data.');
	}
	return {
		id,
		title: movie.title,
		releaseDate:
			typeof movie.release_date === 'string' ? movie.release_date : '',
		overview: typeof movie.overview === 'string' ? movie.overview : '',
		posterPath:
			typeof movie.poster_path === 'string' ? movie.poster_path : null,
		backdropPath:
			typeof movie.backdrop_path === 'string' ? movie.backdrop_path : null
	};
}
