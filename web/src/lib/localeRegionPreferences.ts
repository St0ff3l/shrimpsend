/**
 * Align with Flutter SharedPreferences keys (app/lib/preferences/locale_region_store.dart).
 */
export const STORAGE_LOCALE_TAG = 'ultrasend_locale_tag';
export const STORAGE_SERVICE_REGION = 'ultrasend_service_region';
export const STORAGE_COUNTRY_CODE = 'ultrasend_country_code';
export const STORAGE_GATE_COMPLETED = 'ultrasend_locale_gate_completed';

/** Same-tab listeners (e.g. legal doc links) when country/locale prefs change. */
export const LOCALE_REGION_PREFS_CHANGED_EVENT = 'ultrasend_locale_region_prefs_changed';

export type LocaleTagValue = 'zh_CN' | 'en';

function notifyLocaleRegionPrefsChanged(): void {
  if (typeof window === 'undefined') return;
  window.dispatchEvent(new Event(LOCALE_REGION_PREFS_CHANGED_EVENT));
}

function normalizeCountryCode(raw: string): string {
  const u = raw.trim().toUpperCase();
  if (u.length === 2 && /^[A-Z]{2}$/.test(u)) return u;
  return 'CN';
}

/** ISO alpha-2 from storage, or inferred from legacy region keys; null if unset (same as old “no service_region”). */
export function getRawCountryCode(): string | null {
  if (typeof window === 'undefined') return null;
  const c = localStorage.getItem(STORAGE_COUNTRY_CODE);
  if (c && /^[A-Za-z]{2}$/.test(c)) return c.toUpperCase();
  const legacy = localStorage.getItem(STORAGE_SERVICE_REGION);
  if (legacy === 'international') return 'US';
  if (legacy === 'mainland_china') return 'CN';
  return null;
}

/** Effective country for UI; defaults to CN (matches Flutter after migration). */
export function getStoredCountryCode(): string {
  return getRawCountryCode() ?? 'CN';
}

export function setStoredCountryCode(code: string): void {
  const cc = normalizeCountryCode(code);
  localStorage.setItem(STORAGE_COUNTRY_CODE, cc);
  localStorage.setItem(
    STORAGE_SERVICE_REGION,
    cc === 'CN' ? 'mainland_china' : 'international',
  );
  notifyLocaleRegionPrefsChanged();
}

export function getStoredLocaleTag(): LocaleTagValue {
  if (typeof window === 'undefined') return 'zh_CN';
  const t = localStorage.getItem(STORAGE_LOCALE_TAG);
  return t === 'en' ? 'en' : 'zh_CN';
}

export function getRawLocaleTag(): LocaleTagValue | null {
  if (typeof window === 'undefined') return null;
  const t = localStorage.getItem(STORAGE_LOCALE_TAG);
  if (t === 'en') return 'en';
  if (t === 'zh_CN') return 'zh_CN';
  return null;
}

export function setStoredLocaleTag(tag: LocaleTagValue): void {
  localStorage.setItem(STORAGE_LOCALE_TAG, tag);
  if (typeof document !== 'undefined') {
    document.documentElement.lang = tag === 'zh_CN' ? 'zh-CN' : 'en';
  }
  notifyLocaleRegionPrefsChanged();
}

export interface LocaleRegionSnapshot {
  localeTag: LocaleTagValue;
  countryCode: string;
}

export function readLocaleRegionSnapshot(): LocaleRegionSnapshot {
  return {
    localeTag: getStoredLocaleTag(),
    countryCode: getStoredCountryCode(),
  };
}

export function writeLocaleRegionSnapshot(s: LocaleRegionSnapshot): void {
  setStoredLocaleTag(s.localeTag);
  setStoredCountryCode(s.countryCode);
}
