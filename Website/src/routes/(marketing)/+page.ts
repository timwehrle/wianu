import { fetchWeeklyArchive, fetchWeeklyMovies } from '#lib/weekly/load.js';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch }) => {
	try {
		const archive = await fetchWeeklyArchive(fetch);
		return { movies: await fetchWeeklyMovies(fetch, archive.weeks[0]) };
	} catch {
		return { movies: [] };
	}
};
