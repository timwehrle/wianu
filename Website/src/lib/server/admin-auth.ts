import { env } from '$env/dynamic/private';
import {
	createHmac,
	scrypt as scryptCallback,
	timingSafeEqual
} from 'node:crypto';
import { promisify } from 'node:util';
import type { Cookies } from '@sveltejs/kit';

const cookieName = 'wianu_admin';
const sessionSeconds = 12 * 60 * 60;
const attempts = new Map<string, { count: number; until: number }>();
const scrypt = promisify(scryptCallback);

function signature(
	value: string,
	secret: string,
	passwordHash: string
): string {
	return createHmac('sha256', secret)
		.update(value)
		.update('\0')
		.update(passwordHash)
		.digest('hex');
}

export async function checkPassword(
	password: string,
	client: string
): Promise<boolean> {
	const now = Date.now();
	const attempt = attempts.get(client);

	if (attempt && attempt.until > now && attempt.count >= 5) {
		return false;
	}

	const storedHash = env.WEEKLY_ADMIN_PASSWORD_HASH?.trim();
	const secret = env.WEEKLY_SESSION_SECRET?.trim();
	let valid = false;
	if (storedHash && secret) {
		const parts = storedHash.split(':');
		if (parts.length === 3 && parts[0] === 'scrypt') {
			const salt = Buffer.from(parts[1], 'base64url');
			const expected = Buffer.from(parts[2], 'base64url');
			if (salt.length === 16 && expected.length === 32) {
				const actual = (await scrypt(password, salt, 32)) as Buffer;
				valid = timingSafeEqual(actual, expected);
			}
		}
	}

	if (valid) {
		attempts.delete(client);
		return true;
	}

	attempts.set(client, {
		count: attempt && attempt.until > now ? attempt.count + 1 : 1,
		until: attempt && attempt.until > now ? attempt.until : now + 15 * 60_000
	});

	return false;
}

export function isAdmin(cookies: Cookies): boolean {
	const secret = env.WEEKLY_SESSION_SECRET?.trim();
	const passwordHash = env.WEEKLY_ADMIN_PASSWORD_HASH?.trim();
	const token = cookies.get(cookieName);

	if (!secret || !passwordHash || !token) {
		return false;
	}

	const [expiry, mac] = token.split('.');

	if (!/^\d+$/.test(expiry ?? '') || !/^[a-f0-9]{64}$/.test(mac ?? '')) {
		return false;
	}

	const expiryTime = Number(expiry);

	if (
		!Number.isSafeInteger(expiryTime) ||
		expiryTime < Date.now() ||
		expiryTime > Date.now() + sessionSeconds * 1000
	) {
		return false;
	}

	return timingSafeEqual(
		Buffer.from(mac, 'hex'),
		Buffer.from(signature(expiry, secret, passwordHash), 'hex')
	);
}

export function signIn(cookies: Cookies, secure: boolean): void {
	const secret = env.WEEKLY_SESSION_SECRET?.trim();
	const passwordHash = env.WEEKLY_ADMIN_PASSWORD_HASH?.trim();
	if (!secret || !passwordHash) {
		throw new Error('Weekly admin authentication is not configured');
	}

	const expiry = String(Date.now() + sessionSeconds * 1000);

	cookies.set(
		cookieName,
		`${expiry}.${signature(expiry, secret, passwordHash)}`,
		{
			path: '/',
			httpOnly: true,
			secure,
			sameSite: 'strict',
			maxAge: sessionSeconds
		}
	);
}

export function signOut(cookies: Cookies): void {
	cookies.delete(cookieName, { path: '/' });
}
