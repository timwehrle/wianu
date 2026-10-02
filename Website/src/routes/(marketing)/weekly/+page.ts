import { error } from '@sveltejs/kit';
import { fetchWeeklyArchive, fetchWeeklyMovies } from '#lib/weekly/load.js';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, url }) => {
	let archive;
	try {
		archive = await fetchWeeklyArchive(fetch);
	} catch {
		error(503, 'Weekly selections are unavailable.');
	}

	const requestedWeek = url.searchParams.get('week');
	const selection = requestedWeek
		? archive.weeks.find((entry) => entry.week === requestedWeek)
		: archive.weeks[0];

	if (requestedWeek && !selection) {
		error(404, 'That week was not found.');
	}

	let movies;
	try {
		movies = await fetchWeeklyMovies(fetch, selection);
	} catch {
		error(503, 'Movie details are unavailable.');
	}

	return { archive: archive.weeks, selection: selection ?? null, movies };
};
