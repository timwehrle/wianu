interface Visitor {
	tokens: number;
	lastSeen: number;
}

const RATE_PER_SECOND = 5;
const BURST = 20;
const visitors = new Map<string, Visitor>();
let lastCleanup = Date.now();

export function allowRequest(client: string): boolean {
	const now = Date.now();
	if (now - lastCleanup >= 60_000) {
		for (const [key, visitor] of visitors) {
			if (now - visitor.lastSeen > 10 * 60_000) visitors.delete(key);
		}
		lastCleanup = now;
	}

	const visitor = visitors.get(client) ?? { tokens: BURST, lastSeen: now };
	visitor.tokens = Math.min(
		BURST,
		visitor.tokens + ((now - visitor.lastSeen) / 1000) * RATE_PER_SECOND
	);
	visitor.lastSeen = now;
	visitors.set(client, visitor);
	if (visitor.tokens < 1) return false;
	visitor.tokens -= 1;
	return true;
}
