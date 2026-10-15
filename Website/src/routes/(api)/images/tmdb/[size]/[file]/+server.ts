import type { RequestHandler } from './$types';
import { imageResponse } from '#lib/server/tmdb-images.js';

export const GET: RequestHandler = ({ params }) =>
	imageResponse(params.size, params.file);
