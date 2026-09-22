interface Entry<T> {
	value: T;
	expiresAt: number;
}

export interface CacheResult<T> {
	value: T;
	status: 'hit' | 'miss' | 'coalesced';
}

export class TtlCache<T> {
	private readonly entries = new Map<string, Entry<T>>();
	private readonly pending = new Map<string, Promise<T>>();

	constructor(private readonly maximumEntries: number) {}

	async getOrCreate(
		key: string,
		ttlMilliseconds: number,
		create: () => Promise<T>
	): Promise<CacheResult<T>> {
		const now = Date.now();
		const existing = this.entries.get(key);
		if (existing && existing.expiresAt > now) {
			this.entries.delete(key);
			this.entries.set(key, existing);
			return { value: existing.value, status: 'hit' };
		}
		if (existing) this.entries.delete(key);

		const inFlight = this.pending.get(key);
		if (inFlight) return { value: await inFlight, status: 'coalesced' };

		const request = create().then((value) => {
			this.entries.set(key, { value, expiresAt: Date.now() + ttlMilliseconds });
			while (this.entries.size > this.maximumEntries) {
				const oldest = this.entries.keys().next().value as string | undefined;
				if (oldest === undefined) break;
				this.entries.delete(oldest);
			}
			return value;
		});
		this.pending.set(key, request);
		try {
			return { value: await request, status: 'miss' };
		} finally {
			this.pending.delete(key);
		}
	}
}
