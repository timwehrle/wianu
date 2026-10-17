import type { RequestHandler } from './$types';
import { readWeekly } from '#lib/server/weekly.js';

const origin = 'https://wianu.com';
const publicPaths = ['/', '/the-app', '/weekly', '/privacy-policy', '/imprint'];

function escapeXml(value: string): string {
	return value
		.replaceAll('&', '&amp;')
		.replaceAll('<', '&lt;')
		.replaceAll('>', '&gt;')
		.replaceAll('"', '&quot;')
		.replaceAll("'", '&apos;');
}

export const prerender = false;

export const GET: RequestHandler = async () => {
	const archive = await readWeekly();
	const paths = [
		...publicPaths,
		...archive.weeks.map(
			(entry) => `/weekly?week=${encodeURIComponent(entry.week)}`
		)
	];
	const urls = paths.map(
		(path) => `  <url><loc>${escapeXml(origin + path)}</loc></url>`
	);

	return new Response(
		`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.join('\n')}
</urlset>`,
		{
			headers: {
				'Content-Type': 'application/xml; charset=utf-8',
				'Cache-Control': 'public, max-age=300'
			}
		}
	);
};
