import { error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

type Release = {
	tag_name?: string;
	assets?: { name: string }[];
};

export const GET: RequestHandler = async ({ fetch }) => {
	let response: Response;

	try {
		response = await fetch('https://api.github.com/repos/timwehrle/Wianu/releases/latest', {
			headers: {
				Accept: 'application/vnd.github+json',
				'User-Agent': 'Wianu-website'
			}
		});
	} catch {
		throw error(502, 'The Wianu download is temporarily unavailable.');
	}

	if (!response.ok) {
		throw error(response.status === 404 ? 404 : 502, 'The Wianu download is unavailable.');
	}

	const release = (await response.json()) as Release;
	const tag = release.tag_name;

	if (!tag || !/^v\d+\.\d+\.\d+(?:[.-][A-Za-z0-9.-]+)?$/.test(tag)) {
		throw error(502, 'The latest Wianu release has an unexpected version.');
	}

	const archiveName = `Wianu-${tag.slice(1)}.zip`;

	if (!release.assets?.some((asset) => asset.name === archiveName)) {
		throw error(404, 'The latest Wianu release has no download available.');
	}

	return new Response(null, {
		status: 302,
		headers: {
			Location: `https://github.com/timwehrle/Wianu/releases/download/${tag}/${archiveName}`,
			'Cache-Control': 'no-store'
		}
	});
};
