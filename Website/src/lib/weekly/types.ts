export interface WeeklyMovie {
	id: number;
	title: string;
	releaseDate: string;
	overview: string;
	posterPath: string | null;
	backdropPath: string | null;
}

export type WeeklySelectionMovie = WeeklyMovie & { reason: string };

export interface WeeklyEntry {
	week: string;
	movieIds: number[];
	reasons: Record<string, string>;
	updatedAt: string;
}

export interface WeeklyArchive {
	weeks: WeeklyEntry[];
}
