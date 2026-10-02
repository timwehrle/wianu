import { resolve } from '$app/paths';
import { error } from '@sveltejs/kit';
import type {
	WeeklyArchive,
	WeeklyMovie,
	WeeklySelectionMovie
} from '$lib/server/weekly';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, url }) => {
	const response = await fetch(resolve('/v1/weekly'));
	if (!response.ok) {
		error(503, 'Weekly selections are unavailable.');
	}

	const archive = (await response.json()) as WeeklyArchive;
	const requestedWeek = url.searchParams.get('week');
	const selection = requestedWeek
		? archive.weeks.find((entry) => entry.week === requestedWeek)
		: archive.weeks[0];

	if (requestedWeek && !selection) {
		error(404, 'That week was not found.');
	}

	const movies = await Promise.all(
		(selection?.movieIds ?? []).map(async (id) => {
			const details = await fetch(resolve(`/v1/movie/${id}`));
			if (!details.ok) {
				error(503, 'Movie details are unavailable.');
			}
			return {
				...((await details.json()) as WeeklyMovie),
				reason: selection?.reasons[id] ?? ''
			} satisfies WeeklySelectionMovie;
		})
	);

	return { archive: archive.weeks, selection: selection ?? null, movies };
};
