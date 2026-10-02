import { resolve } from '$app/paths';
import type {
	WeeklyArchive,
	WeeklyEntry,
	WeeklyMovie,
	WeeklySelectionMovie
} from './types';

export async function fetchWeeklyArchive(
	fetch: typeof globalThis.fetch
): Promise<WeeklyArchive> {
	const response = await fetch(resolve('/v1/weekly'));
	if (!response.ok) {
		throw new Error('Weekly selections are unavailable.');
	}
	return (await response.json()) as WeeklyArchive;
}

export async function fetchWeeklyMovies(
	fetch: typeof globalThis.fetch,
	selection: WeeklyEntry | undefined
): Promise<WeeklySelectionMovie[]> {
	return Promise.all(
		(selection?.movieIds ?? []).map(async (id) => {
			const response = await fetch(resolve(`/v1/movie/${id}`));
			if (!response.ok) {
				throw new Error('Movie details are unavailable.');
			}
			return {
				...((await response.json()) as WeeklyMovie),
				reason: selection?.reasons[id] ?? ''
			} satisfies WeeklySelectionMovie;
		})
	);
}
