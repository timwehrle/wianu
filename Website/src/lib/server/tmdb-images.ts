import { TtlCache } from './cache.ts';

const sizes = new Set(['w92', 'w500', 'w780', 'w1280']);
const maxImageBytes = 4 * 1024 * 1024;
const images = new TtlCache<{ bytes: Uint8Array<ArrayBuffer>; type: string }>(
	32
);

export function imagePath(size: string, file: string): string | null {
	return sizes.has(size) && /^[a-zA-Z0-9_-]{1,128}\.(jpg|png|webp)$/.test(file)
		? `/t/p/${size}/${file}`
		: null;
}

export async function imageResponse(
	size: string,
	file: string,
	requestImage: typeof fetch = fetch
): Promise<Response> {
	const path = imagePath(size, file);
	if (!path) {
		return new Response('Image not found.', { status: 404 });
	}
	try {
		const { value } = await images.getOrCreate(
			path,
			24 * 60 * 60_000,
			async () => {
				// Use a fresh server request: never forward visitor cookies, IP or browser headers.
				const upstream = await requestImage(`https://image.tmdb.org${path}`, {
					headers: { accept: 'image/jpeg, image/png, image/webp' },
					redirect: 'error',
					signal: AbortSignal.timeout(8_000)
				});
				const type = upstream.headers.get('content-type')?.split(';')[0].trim();
				if (
					!upstream.ok ||
					!type ||
					!['image/jpeg', 'image/png', 'image/webp'].includes(type) ||
					Number(upstream.headers.get('content-length')) > maxImageBytes ||
					!upstream.body
				) {
					await upstream.body?.cancel();
					throw new Error('Invalid image response');
				}
				const reader = upstream.body.getReader();
				const chunks: Uint8Array[] = [];
				let length = 0;
				while (true) {
					const { done, value } = await reader.read();
					if (done) {
						break;
					}
					length += value.byteLength;
					if (length > maxImageBytes) {
						await reader.cancel();
						throw new Error('Image too large');
					}
					chunks.push(value);
				}
				if (length === 0) {
					throw new Error('Empty image');
				}
				const bytes = new Uint8Array(length);
				let offset = 0;
				for (const chunk of chunks) {
					bytes.set(chunk, offset);
					offset += chunk.byteLength;
				}
				return { bytes, type };
			}
		);
		return new Response(value.bytes, {
			headers: {
				'content-type': value.type,
				'cache-control': 'public, max-age=86400',
				'x-content-type-options': 'nosniff'
			}
		});
	} catch {
		return new Response('Image temporarily unavailable.', {
			status: 502,
			headers: { 'cache-control': 'no-store' }
		});
	}
}
