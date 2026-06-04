import type { Metadata } from 'next';
import { headers } from 'next/headers';
import { notFound } from 'next/navigation';
import { LandingPage } from '@/components/landing/LandingPage';
import { isLocalePath } from '@/lib/i18nRouting';
import { DEFAULT_OG_IMAGE, SITE_LOCALE, SITE_NAME, absoluteUrl, getSiteOriginFromHost, localizedAlternates } from '@/lib/seo';
import zhMessages from '@/messages/zh.json';
import enMessages from '@/messages/en.json';

const MESSAGES = {
  zh: zhMessages,
  en: enMessages,
} as const;

export function generateStaticParams() {
  return [{ lang: 'zh' }, { lang: 'en' }];
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ lang: string }>;
}): Promise<Metadata> {
  const { lang } = await params;
  if (!isLocalePath(lang)) return {};
  const messages = MESSAGES[lang];
  const origin = getSiteOriginFromHost((await headers()).get('host'));
  const canonicalPath = `/${lang}`;
  return {
    title: { absolute: messages.metadata.title },
    description: messages.metadata.description,
    alternates: localizedAlternates(lang, (locale) => `/${locale}`, origin),
    openGraph: {
      type: 'website',
      locale: SITE_LOCALE[lang],
      alternateLocale: lang === 'zh' ? [SITE_LOCALE.en] : [SITE_LOCALE.zh],
      url: absoluteUrl(canonicalPath, origin),
      siteName: SITE_NAME[lang],
      title: messages.metadata.title,
      description: messages.metadata.description,
      images: [{ url: absoluteUrl(DEFAULT_OG_IMAGE, origin), alt: messages.metadata.title }],
    },
    twitter: {
      card: 'summary_large_image',
      title: messages.metadata.title,
      description: messages.metadata.description,
      images: [absoluteUrl(DEFAULT_OG_IMAGE, origin)],
    },
  };
}

export default async function LocalizedHomePage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!isLocalePath(lang)) notFound();
  const origin = getSiteOriginFromHost((await headers()).get('host'));

  return <LandingPage localePath={lang} siteOrigin={origin} />;
}
