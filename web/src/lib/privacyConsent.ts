export const COOKIE_CONSENT_KEY = 'ultrasend-cookie-consent-v2';
export const LEGACY_COOKIE_CONSENT_KEY = 'ultrasend-cookie-consent-v1';
export const COOKIE_CONSENT_EVENT = 'ultrasend-cookie-consent-change';

export type CookieConsentValue = 'all' | 'necessary';

export function readCookieConsent(): CookieConsentValue | null {
  if (typeof window === 'undefined') return null;
  try {
    const current = localStorage.getItem(COOKIE_CONSENT_KEY);
    if (current === 'all' || current === 'necessary') return current;

    // Treat the old single-button consent as analytics consent so returning users
    // do not see the banner again after the preference schema migration.
    if (localStorage.getItem(LEGACY_COOKIE_CONSENT_KEY) === 'accepted') return 'all';
  } catch {
    return null;
  }
  return null;
}

export function writeCookieConsent(value: CookieConsentValue): void {
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(COOKIE_CONSENT_KEY, value);
    localStorage.removeItem(LEGACY_COOKIE_CONSENT_KEY);
  } catch {
    // Ignore storage failures; the current session can still continue.
  }
  window.dispatchEvent(new CustomEvent(COOKIE_CONSENT_EVENT, { detail: value }));
}

export function hasAnalyticsConsent(): boolean {
  return readCookieConsent() === 'all';
}
