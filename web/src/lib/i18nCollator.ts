import type { LocaleTagValue } from '@/lib/localeRegionPreferences';

/** Device/name sorting aligned with current UI language (replaces hard-coded zh-Hans). */
export function collatorForLocaleTag(tag: LocaleTagValue): Intl.Collator {
  const loc = tag === 'zh_CN' ? 'zh-Hans-CN' : 'en';
  return new Intl.Collator(loc, { sensitivity: 'base' });
}
