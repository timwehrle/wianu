import type { WeeklyEntry } from '#lib/weekly/types.js';

export const year = (date: string) => date.slice(0, 4);

// Calendar-week keys remain stable archive URLs; issue numbers count published selections.
export const issueNumber = (selection: WeeklyEntry, archive: WeeklyEntry[]) =>
	String(
		archive.filter(
			(entry) =>
				entry.week.slice(0, 4) === selection.week.slice(0, 4) &&
				entry.week <= selection.week
		).length
	).padStart(2, '0');
