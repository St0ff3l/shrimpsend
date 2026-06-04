import type { Metadata } from 'next';
import type { DocsDocId } from '@/lib/docsMarkdown';
import { BRAND_LOGO_PNG_SRC } from '@/lib/brandAssets';
import { DOC_PATHS, LOCALE_PATHS, localizedDocsHref, localizedHomeHref, type LocalePath } from '@/lib/i18nRouting';

export const DEFAULT_MAINLAND_ORIGIN = 'https://xiachuan.net';
export const DEFAULT_OVERSEAS_ORIGIN = 'https://shrimpsend.com';
export const DEFAULT_OG_IMAGE = BRAND_LOGO_PNG_SRC;

export const SITE_NAME: Record<LocalePath, string> = {
  zh: '虾传',
  en: 'ShrimpSend',
};

export const SITE_LOCALE: Record<LocalePath, string> = {
  zh: 'zh_CN',
  en: 'en_US',
};

export const HREFLANG: Record<LocalePath, string> = {
  zh: 'zh-CN',
  en: 'en',
};

export const appRobotsNoIndex: Metadata['robots'] = {
  index: false,
  follow: false,
  googleBot: {
    index: false,
    follow: false,
  },
};

export const appRobotsIndex: Metadata['robots'] = {
  index: true,
  follow: true,
  googleBot: {
    index: true,
    follow: true,
    'max-image-preview': 'large',
    'max-snippet': -1,
    'max-video-preview': -1,
  },
};

export const privateAppPaths = [
  '/admin',
  '/chat',
  '/devices',
  '/search',
  '/settings',
  '/login',
  '/register',
] as const;

export function normalizeOrigin(value: string | undefined | null): string | null {
  if (!value) return null;
  const trimmed = value.trim().replace(/\/+$/, '');
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    return url.origin;
  } catch {
    return null;
  }
}

export function getConfiguredSiteOrigin(): string {
  return (
    normalizeOrigin(process.env.NEXT_PUBLIC_WEB_BASE_URL) ??
    normalizeOrigin(process.env.NEXT_PUBLIC_SITE_URL) ??
    normalizeOrigin(process.env.APP_PUBLIC_WEB_BASE_URL) ??
    DEFAULT_MAINLAND_ORIGIN
  );
}

export function getSiteOriginFromHost(host: string | null | undefined): string {
  const normalizedHost = host?.toLowerCase() ?? '';
  if (normalizedHost.includes('shrimpsend.com') || normalizedHost.includes('shrimpsend')) {
    return DEFAULT_OVERSEAS_ORIGIN;
  }
  if (normalizedHost.includes('xiachuan.net') || normalizedHost.includes('xiachuan')) {
    return DEFAULT_MAINLAND_ORIGIN;
  }
  return getConfiguredSiteOrigin();
}

export function absoluteUrl(path: string, origin = getConfiguredSiteOrigin()): string {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${origin}${normalizedPath}`;
}

export function localeAlternates(pathForLocale: (locale: LocalePath) => string, origin = getConfiguredSiteOrigin()) {
  return {
    canonical: absoluteUrl(pathForLocale('zh'), origin),
    languages: {
      [HREFLANG.zh]: absoluteUrl(pathForLocale('zh'), origin),
      [HREFLANG.en]: absoluteUrl(pathForLocale('en'), origin),
      'x-default': absoluteUrl(pathForLocale('en'), origin),
    },
  };
}

export function localizedAlternates(locale: LocalePath, pathForLocale: (locale: LocalePath) => string, origin = getConfiguredSiteOrigin()) {
  return {
    canonical: absoluteUrl(pathForLocale(locale), origin),
    languages: {
      [HREFLANG.zh]: absoluteUrl(pathForLocale('zh'), origin),
      [HREFLANG.en]: absoluteUrl(pathForLocale('en'), origin),
      'x-default': absoluteUrl(pathForLocale('en'), origin),
    },
  };
}

export function publicPagePaths(): string[] {
  const homePaths = LOCALE_PATHS.map((locale) => localizedHomeHref(locale));
  const docPaths = LOCALE_PATHS.flatMap((locale) => DOC_PATHS.map((doc) => localizedDocsHref(locale, doc)));
  const legalPaths = [
    '/legal/cn/privacy',
    '/legal/cn/terms',
    '/legal/intl/zh/privacy',
    '/legal/intl/zh/terms',
    '/legal/intl/en/privacy',
    '/legal/intl/en/terms',
  ];
  return [...homePaths, ...docPaths, ...legalPaths];
}

export function docsPathForLocale(locale: LocalePath, doc: DocsDocId): string {
  return localizedDocsHref(locale, doc);
}

export function publicMetadata({
  title,
  description,
  path,
  locale,
  origin = getConfiguredSiteOrigin(),
  type = 'website',
}: {
  title: string;
  description: string;
  path: string;
  locale: LocalePath;
  origin?: string;
  type?: 'website' | 'article';
}): Metadata {
  return {
    title: { absolute: title },
    description,
    alternates: {
      canonical: absoluteUrl(path, origin),
    },
    openGraph: {
      type,
      locale: SITE_LOCALE[locale],
      url: absoluteUrl(path, origin),
      siteName: SITE_NAME[locale],
      title,
      description,
      images: [{ url: absoluteUrl(DEFAULT_OG_IMAGE, origin), alt: title }],
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [absoluteUrl(DEFAULT_OG_IMAGE, origin)],
    },
  };
}
