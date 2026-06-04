/**
 * Tracks transfer speed using exponential smoothing.
 *
 * Call {@link update} whenever new bytes-received data is available.
 * Read {@link bytesPerSecond} or {@link formatted} for the current speed.
 */
export class SpeedTracker {
  private lastBytes = 0;
  private lastTime = Date.now();
  private speed = 0;

  update(currentBytes: number): number {
    const now = Date.now();
    const elapsedMs = now - this.lastTime;
    if (elapsedMs < 200) return this.speed;

    const delta = currentBytes - this.lastBytes;
    if (delta > 0) {
      const instantaneous = delta / (elapsedMs / 1000);
      this.speed = this.speed === 0
        ? instantaneous
        : this.speed * 0.3 + instantaneous * 0.7;
    }
    this.lastBytes = currentBytes;
    this.lastTime = now;
    return this.speed;
  }

  get bytesPerSecond(): number {
    return this.speed;
  }

  get formatted(): string {
    return formatSpeed(this.speed);
  }

  reset(): void {
    this.lastBytes = 0;
    this.lastTime = Date.now();
    this.speed = 0;
  }
}

export function formatSpeed(bytesPerSec: number): string {
  if (bytesPerSec <= 0) return '';
  if (bytesPerSec < 1024) return `${Math.round(bytesPerSec)} B/s`;
  if (bytesPerSec < 1024 * 1024) return `${(bytesPerSec / 1024).toFixed(1)} KB/s`;
  if (bytesPerSec < 1024 * 1024 * 1024) return `${(bytesPerSec / (1024 * 1024)).toFixed(1)} MB/s`;
  return `${(bytesPerSec / (1024 * 1024 * 1024)).toFixed(2)} GB/s`;
}
