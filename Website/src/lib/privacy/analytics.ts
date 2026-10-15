export const consentCookie = 'wianu_analytics_consent';
export const consentMaxAge = 180 * 24 * 60 * 60;
export const websiteId = '52f5d899-2f07-4c6a-8996-fbb33bac6f9e';
export const trackerUrl = 'https://analytics.timwehrle.de/app.js';
export const settingsEvent = 'wianu:privacy-settings';

export type AnalyticsConsent = 'granted' | 'denied';

export function readConsent(cookies: string): AnalyticsConsent | null {
	const value = cookies
		.split(';')
		.map((cookie) => cookie.trim())
		.find((cookie) => cookie.startsWith(`${consentCookie}=`))
		?.slice(consentCookie.length + 1);
	if (value === 'v1.granted') {
		return 'granted';
	}
	if (value === 'v1.denied') {
		return 'denied';
	}
	return null;
}

export function consentCookieValue(
	choice: AnalyticsConsent,
	secure: boolean
): string {
	return `${consentCookie}=v1.${choice}; Path=/; Max-Age=${consentMaxAge}; SameSite=Lax${secure ? '; Secure' : ''}`;
}

export function isAdminPath(pathname: string): boolean {
	return pathname.split('/').includes('admin');
}

export function cleanReferrer(value: string): string {
	try {
		const url = new URL(value);
		return url.protocol === 'https:' || url.protocol === 'http:'
			? `${url.origin}${url.pathname}`
			: '';
	} catch {
		return '';
	}
}

export function openPrivacySettings(event?: MouseEvent): void {
	const trigger = event?.currentTarget;
	window.dispatchEvent(
		new CustomEvent(settingsEvent, {
			detail: { trigger: trigger instanceof HTMLElement ? trigger : null }
		})
	);
}
