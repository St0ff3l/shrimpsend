import type { TranslateFn } from '@/contexts/I18nContext';

/** Returns true if `s` looks like a dotted i18n key from our JSON (not raw API text). */
export function isI18nKey(s: string): boolean {
  return /^(common|auth|settings|chat|errors|devices|search|download|metadata|membership|s3|account|about|appearance|sendPanel|deviceList|fileCard|fileDownload|image)\.[a-zA-Z0-9._]+$/.test(
    s,
  );
}

/** Translate known keys; pass through server/user-facing raw strings. */
export function formatUiMessage(raw: string | null | undefined, t: TranslateFn): string {
  if (raw == null || raw === '') return '';
  if (isI18nKey(raw)) return t(raw);
  return raw;
}
