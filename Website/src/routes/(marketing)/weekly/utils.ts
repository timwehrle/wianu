import type { WeeklyEntry } from '#lib/weekly/types.js';

export const year = (date: string) => date.slice(0, 4);

// Label the issue by its ISO week's Monday, independent of later edits.
export function issueDate(week: string) {
	const [year, number] = week.split('-W').map(Number);
	const date = new Date(Date.UTC(year, 0, 4));
	date.setUTCDate(
		date.getUTCDate() - ((date.getUTCDay() + 6) % 7) + (number - 1) * 7
	);
	return new Intl.DateTimeFormat('en-GB', {
		day: 'numeric',
		month: 'short',
		year: 'numeric',
		timeZone: 'UTC'
	}).format(date);
}

// Calendar-week keys remain stable archive URLs; issue numbers count published selections.
export const issueNumber = (selection: WeeklyEntry, archive: WeeklyEntry[]) =>
	String(
		archive.filter(
			(entry) =>
				entry.week.slice(0, 4) === selection.week.slice(0, 4) &&
				entry.week <= selection.week
		).length
	).padStart(2, '0');
