/**
 * 统一的 SHA-256 / HMAC-SHA256 接口，兼容非安全上下文（如 http://192.168.x.x）。
 * 在部分手机浏览器中，通过 HTTP 访问时 crypto.subtle 为 undefined，会导致 S3 签名等报错。
 * 此处优先使用 Web Crypto API，不可用时回退到 js-sha256。
 */

import { sha256 as jsSha256 } from 'js-sha256';

const encoder = new TextEncoder();

function hasSubtle(): boolean {
  return typeof crypto !== 'undefined' && typeof crypto.subtle === 'object';
}

function bufToHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/** SHA-256 哈希，返回十六进制字符串。 */
export async function sha256Hex(data: string): Promise<string> {
  if (hasSubtle()) {
    const buf = await crypto.subtle.digest('SHA-256', encoder.encode(data) as BufferSource);
    return bufToHex(buf);
  }
  return jsSha256(data);
}

/** SHA-256 哈希任意二进制，返回十六进制字符串。 */
export async function sha256HexBytes(data: ArrayBuffer | Uint8Array): Promise<string> {
  if (hasSubtle()) {
    const buf = await crypto.subtle.digest('SHA-256', data as BufferSource);
    return bufToHex(buf);
  }
  const bytes = data instanceof ArrayBuffer ? new Uint8Array(data) : data;
  return jsSha256(bytes);
}

/** HMAC-SHA256(key, data)，返回二进制。用于 AWS 签名等。key 可为 ArrayBuffer 或 Uint8Array。 */
export async function hmacSha256(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const keyBytes = key instanceof ArrayBuffer ? new Uint8Array(key) : key;
  if (hasSubtle()) {
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyBytes as BufferSource,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    return crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(data) as BufferSource);
  }
  const out = jsSha256.hmac.arrayBuffer(keyBytes, data);
  return out;
}

/** HMAC-SHA256(key, data)，返回十六进制字符串。 */
export async function hmacSha256Hex(key: ArrayBuffer, data: string): Promise<string> {
  const sig = await hmacSha256(key, data);
  return bufToHex(sig);
}

/** 对 ArrayBuffer 做 SHA-256 digest，返回原始 ArrayBuffer。供 fileHash 等使用。 */
export async function sha256Digest(buffer: ArrayBuffer): Promise<ArrayBuffer> {
  if (hasSubtle()) {
    return crypto.subtle.digest('SHA-256', buffer as BufferSource);
  }
  return jsSha256.arrayBuffer(new Uint8Array(buffer)) as ArrayBuffer;
}
