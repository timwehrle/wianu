import { json } from '@sveltejs/kit';

export function GET(): Response {
	return json({ status: 'ok' }, { headers: { 'cache-control': 'no-store' } });
}
