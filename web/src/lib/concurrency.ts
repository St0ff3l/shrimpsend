/**
 * Run async work over `items` with at most `concurrency` tasks in flight.
 */
export async function runWithConcurrency<T>(
  items: readonly T[],
  concurrency: number,
  worker: (item: T, index: number) => Promise<void>,
): Promise<void> {
  if (items.length === 0) return;
  const limit = Math.max(1, concurrency);
  let nextIndex = 0;

  async function runWorker(): Promise<void> {
    while (true) {
      const i = nextIndex++;
      if (i >= items.length) return;
      await worker(items[i], i);
    }
  }

  const workers = Array.from({ length: Math.min(limit, items.length) }, () => runWorker());
  await Promise.all(workers);
}

/** Limits concurrent async regions (e.g. inbound LAN pulls). */
export class AsyncSemaphore {
  private waiters: Array<() => void> = [];
  private active = 0;

  constructor(private readonly max: number) {}

  async acquire(): Promise<void> {
    if (this.active < this.max) {
      this.active += 1;
      return;
    }
    await new Promise<void>((resolve) => {
      this.waiters.push(resolve);
    });
    this.active += 1;
  }

  release(): void {
    this.active -= 1;
    const next = this.waiters.shift();
    if (next) next();
  }
}
