import { hmacSha256 as hmacSha256Async, hmacSha256Hex, sha256Hex } from '@/lib/cryptoHash';

const encoder = new TextEncoder();

async function hmacSha256(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  return hmacSha256Async(key, data);
}

function bufToHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function dateStamp(dt: Date): string {
  return dt.toISOString().slice(0, 10).replace(/-/g, '');
}

function amzDate(dt: Date): string {
  return dt.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

function uriEncode(value: string): string {
  return encodeURIComponent(value).replace(/%20/g, '%20');
}

function uriEncodePath(path: string): string {
  return path
    .split('/')
    .map((s) => uriEncode(s))
    .join('/');
}

async function deriveSigningKey(
  secretKey: string,
  ds: string,
  region: string,
  service: string,
): Promise<ArrayBuffer> {
  const kDate = await hmacSha256(encoder.encode('AWS4' + secretKey), ds);
  const kRegion = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, service);
  return hmacSha256(kService, 'aws4_request');
}

export interface PresignOptions {
  method: string;
  url: URL;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
  service?: string;
  expireSeconds?: number;
}

export async function presignUrl(opts: PresignOptions): Promise<string> {
  const {
    method,
    url,
    accessKeyId,
    secretAccessKey,
    region,
    service = 's3',
    expireSeconds = 3600,
  } = opts;

  const now = new Date();
  const ds = dateStamp(now);
  const amz = amzDate(now);
  const scope = `${ds}/${region}/${service}/aws4_request`;

  const host = url.port && url.port !== '443' && url.port !== '80'
    ? `${url.hostname}:${url.port}`
    : url.hostname;

  const signedHeaders = 'host';

  const params = new URLSearchParams(url.search);
  params.set('X-Amz-Algorithm', 'AWS4-HMAC-SHA256');
  params.set('X-Amz-Credential', `${accessKeyId}/${scope}`);
  params.set('X-Amz-Date', amz);
  params.set('X-Amz-Expires', String(expireSeconds));
  params.set('X-Amz-SignedHeaders', signedHeaders);

  const sortedParams = [...params.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  const canonicalQueryString = sortedParams
    .map(([k, v]) => `${uriEncode(k)}=${uriEncode(v)}`)
    .join('&');

  const canonicalRequest = [
    method.toUpperCase(),
    uriEncodePath(url.pathname || '/'),
    canonicalQueryString,
    `host:${host}\n`,
    signedHeaders,
    'UNSIGNED-PAYLOAD',
  ].join('\n');

  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amz,
    scope,
    await sha256Hex(canonicalRequest),
  ].join('\n');

  const signingKey = await deriveSigningKey(secretAccessKey, ds, region, service);
  const signature = await hmacSha256Hex(signingKey, stringToSign);

  return `${url.origin}${url.pathname}?${canonicalQueryString}&X-Amz-Signature=${signature}`;
}

export interface SignRequestOptions {
  method: string;
  url: URL;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
  service?: string;
  headers?: Record<string, string>;
  bodyHash?: string;
}

export async function signRequest(opts: SignRequestOptions): Promise<Record<string, string>> {
  const {
    method,
    url,
    accessKeyId,
    secretAccessKey,
    region,
    service = 's3',
    headers: extraHeaders = {},
    bodyHash,
  } = opts;

  const now = new Date();
  const ds = dateStamp(now);
  const amz = amzDate(now);
  const scope = `${ds}/${region}/${service}/aws4_request`;
  const payloadHash = bodyHash ?? await sha256Hex('');

  const host = url.port && url.port !== '443' && url.port !== '80'
    ? `${url.hostname}:${url.port}`
    : url.hostname;

  const allHeaders: Record<string, string> = {
    host,
    'x-amz-date': amz,
    'x-amz-content-sha256': payloadHash,
    ...extraHeaders,
  };

  const signedHeadersList = Object.keys(allHeaders)
    .map((k) => k.toLowerCase())
    .sort();
  const signedHeaders = signedHeadersList.join(';');

  const sortedParams = [...url.searchParams.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  const queryString = sortedParams
    .map(([k, v]) => `${uriEncode(k)}=${uriEncode(v)}`)
    .join('&');

  const canonicalHeaders = signedHeadersList
    .map((h) => `${h}:${(allHeaders[h] ?? '').trim()}\n`)
    .join('');

  const canonicalRequest = [
    method.toUpperCase(),
    uriEncodePath(url.pathname || '/'),
    queryString,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');

  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amz,
    scope,
    await sha256Hex(canonicalRequest),
  ].join('\n');

  const signingKey = await deriveSigningKey(secretAccessKey, ds, region, service);
  const signature = await hmacSha256Hex(signingKey, stringToSign);

  return {
    Authorization: `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
    'x-amz-date': amz,
    'x-amz-content-sha256': payloadHash,
  };
}
