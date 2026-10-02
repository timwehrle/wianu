import { resolve } from '$app/paths';
import type {
	WeeklyArchive,
	WeeklyMovie,
	WeeklySelectionMovie
} from '$lib/server/weekly';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch }) => {
	try {
		const response = await fetch(resolve('/v1/weekly'));
		if (!response.ok) {
			return { movies: [] };
		}

		const archive = (await response.json()) as WeeklyArchive;
		const movieIds = archive.weeks[0]?.movieIds ?? [];
		const reasons = archive.weeks[0]?.reasons ?? {};
		const movies = await Promise.all(
			movieIds.map(async (id) => {
				const details = await fetch(resolve(`/v1/movie/${id}`));
				if (!details.ok) {
					throw new Error('Movie details are unavailable.');
				}
				return {
					...((await details.json()) as WeeklyMovie),
					reason: reasons[id] ?? ''
				} satisfies WeeklySelectionMovie;
			})
		);

		return { movies };
	} catch {
		return { movies: [] };
	}
};
