const KEY_ID = 'ultrasend_device_id';
const KEY_NAME = 'ultrasend_device_name';
const KEY_PRESENCE_SESSION_ID = 'ultrasend_presence_session_id';

function detectBrowser(): string {
  const ua = navigator.userAgent;
  if (ua.includes('Edg/')) return 'edge';
  if (ua.includes('OPR/') || ua.includes('Opera')) return 'opera';
  if (ua.includes('Firefox/')) return 'firefox';
  if (ua.includes('Chrome/') && ua.includes('Safari/')) return 'chrome';
  if (ua.includes('Safari/') && !ua.includes('Chrome/')) return 'safari';
  return 'browser';
}

function detectOS(): string {
  const ua = navigator.userAgent;
  if (ua.includes('iPhone') || ua.includes('iPad')) return 'iOS';
  if (ua.includes('Android')) return 'Android';
  if (ua.includes('Mac OS X')) return 'macOS';
  if (ua.includes('Windows')) return 'Windows';
  if (ua.includes('Linux')) return 'Linux';
  if (ua.includes('CrOS')) return 'ChromeOS';
  return 'Web';
}

const browserDisplayNames: Record<string, string> = {
  chrome: 'Chrome',
  firefox: 'Firefox',
  safari: 'Safari',
  edge: 'Edge',
  opera: 'Opera',
  browser: 'Browser',
};

function generateDeviceName(): string {
  const browser = detectBrowser();
  const os = detectOS();
  return `${browserDisplayNames[browser] || browser} · ${os}`;
}

function isLegacyId(id: string): boolean {
  return id.startsWith('web_');
}

function isLegacyName(name: string): boolean {
  return name === 'Web';
}

/** 生成 UUID v4，兼容不支持 crypto.randomUUID 的旧版/部分手机浏览器。可供其他模块复用。 */
export function generateUUID(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  // 使用 getRandomValues 作为兜底（支持更广，包括部分 Android 内置浏览器）
  const bytes = new Uint8Array(16);
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    crypto.getRandomValues(bytes);
  } else {
    for (let i = 0; i < 16; i++) bytes[i] = Math.floor(Math.random() * 256);
  }
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function getOrCreateDeviceId(): string {
  if (typeof window === 'undefined') return '';
  let id = localStorage.getItem(KEY_ID);
  if (!id || isLegacyId(id)) {
    const prefix = detectBrowser();
    const uuid = generateUUID();
    id = `${prefix}_${uuid}`;
    localStorage.setItem(KEY_ID, id);
  }
  return id;
}

export function getDeviceName(): string {
  if (typeof window === 'undefined') return 'Web';
  let name = localStorage.getItem(KEY_NAME);
  if (!name || isLegacyName(name)) {
    name = generateDeviceName();
    localStorage.setItem(KEY_NAME, name);
  }
  return name;
}

export function getOrCreatePresenceSessionId(): string {
  if (typeof window === 'undefined') return '';
  let id = sessionStorage.getItem(KEY_PRESENCE_SESSION_ID);
  if (!id) {
    id = generateUUID();
    sessionStorage.setItem(KEY_PRESENCE_SESSION_ID, id);
  }
  return id;
}

export function setDeviceName(name: string): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(KEY_NAME, name);
}
