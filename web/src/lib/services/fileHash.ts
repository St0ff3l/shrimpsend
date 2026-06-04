import { sha256Digest } from '@/lib/cryptoHash';

/**
 * Compute SHA-256 hash of a File.
 * Uses Web Crypto when available; falls back to js-sha256 in non-secure contexts (e.g. http://192.168.x.x).
 */
export async function computeFileHash(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const hash = await sha256Digest(buffer);
  return hexEncode(hash);
}

/**
 * Compute SHA-256 hash of an ArrayBuffer.
 */
export async function computeBufferHash(buffer: ArrayBuffer): Promise<string> {
  const hash = await sha256Digest(buffer);
  return hexEncode(hash);
}

function hexEncode(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
