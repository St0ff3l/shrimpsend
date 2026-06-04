import type { LocaleTagValue } from '@/lib/localeRegionPreferences';
import { isS3SectionId, type DocsDocId, type S3SectionId } from '@/lib/docsConfig';

export type LocalePath = 'zh' | 'en';

export const LOCALE_PATHS: LocalePath[] = ['zh', 'en'];
export const DOC_PATHS: DocsDocId[] = ['intro', 's3', 'privacy', 'terms', 'contact'];

export function isLocalePath(value: string): value is LocalePath {
  return value === 'zh' || value === 'en';
}

export function isDocsDocId(value: string): value is DocsDocId {
  return DOC_PATHS.includes(value as DocsDocId);
}

export function localePathToTag(locale: LocalePath): LocaleTagValue {
  return locale === 'en' ? 'en' : 'zh_CN';
}

export function localeTagToPath(tag: LocaleTagValue): LocalePath {
  return tag === 'en' ? 'en' : 'zh';
}

export function localePathToDocsLocale(locale: LocalePath): 'zh' | 'en' {
  return locale === 'en' ? 'en' : 'zh';
}

export function localizedHomeHref(locale: LocalePath): string {
  return `/${locale}`;
}

export function localizedDocsHref(
  locale: LocalePath,
  doc: DocsDocId = 'intro',
  section?: S3SectionId,
): string {
  if (doc === 's3') {
    const s3Section = section ?? 'overview';
    return `/${locale}/docs/s3/${s3Section}`;
  }
  return `/${locale}/docs/${doc}`;
}

/** Derive active docs nav from the URL (client navigations may lag server `initial*` props). */
export function parseDocsPathname(pathname: string): {
  doc: DocsDocId;
  s3Section?: S3SectionId;
} | null {
  const parts = pathname.split('/').filter(Boolean);
  if (parts.length < 3 || !isLocalePath(parts[0]) || parts[1] !== 'docs') return null;
  const docSegment = parts[2];
  if (docSegment === 's3') {
    const raw = parts[3];
    const s3Section = raw && isS3SectionId(raw) ? raw : 'overview';
    return { doc: 's3', s3Section };
  }
  if (isDocsDocId(docSegment)) return { doc: docSegment };
  return null;
}

export function localizedHashHref(locale: LocalePath, hash: string): string {
  return `/${locale}#${hash}`;
}

export function switchLocalePath(pathname: string, targetLocale: LocalePath): string {
  const parts = pathname.split('/').filter(Boolean);
  if (parts.length === 0) return localizedHomeHref(targetLocale);
  if (isLocalePath(parts[0])) {
    parts[0] = targetLocale;
    return `/${parts.join('/')}`;
  }
  return localizedHomeHref(targetLocale);
}
