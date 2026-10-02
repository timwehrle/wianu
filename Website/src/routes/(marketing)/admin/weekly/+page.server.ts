import { fail, redirect } from '@sveltejs/kit';
import { ApiError } from '#lib/server/api.js';
import {
	checkPassword,
	isAdmin,
	signIn,
	signOut
} from '#lib/server/admin-auth.js';
import { getMovie, publishWeekly, readWeekly } from '#lib/server/weekly.js';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ cookies, locals }) => {
	if (!isAdmin(cookies)) {
		return { authenticated: false, selection: null, archive: [], movies: [] };
	}

	const archive = (await readWeekly()).weeks;

	const selection = archive[0] ?? null;

	return {
		authenticated: true,
		selection,
		archive,
		movies: selection
			? await Promise.all(
					selection.movieIds.map((id) => getMovie(id, locals.requestId))
				)
			: []
	};
};

export const actions: Actions = {
	login: async ({ cookies, request, url, getClientAddress }) => {
		const password = (await request.formData()).get('password');
		if (
			typeof password !== 'string' ||
			!(await checkPassword(password, getClientAddress()))
		) {
			return fail(401, {
				message: 'Incorrect password or admin access is not configured.'
			});
		}

		signIn(cookies, url.protocol === 'https:');
		redirect(303, '/admin/weekly');
	},

	logout: async ({ cookies }) => {
		signOut(cookies);
		redirect(303, '/admin/weekly');
	},

	save: async ({ cookies, request, locals }) => {
		if (!isAdmin(cookies)) {
			return fail(401, { message: 'Sign in again to publish.' });
		}

		const form = await request.formData();
		const ids = form.getAll('movieId').map((value) => Number(value));
		const reasons = form.getAll('reason');

		try {
			await publishWeekly(ids, reasons, locals.requestId);
		} catch (error) {
			if (error instanceof ApiError) {
				return fail(error.status, { message: error.message });
			}
			throw error;
		}

		return { message: 'Weekly selection published.' };
	}
};
