import { notFound } from 'next/navigation';
import { I18nProvider } from '@/contexts/I18nContext';
import { isLocalePath, localePathToTag, LOCALE_PATHS } from '@/lib/i18nRouting';

export function generateStaticParams() {
  return LOCALE_PATHS.map((lang) => ({ lang }));
}

export default async function LocaleLayout({
  children,
  params,
}: Readonly<{
  children: React.ReactNode;
  params: Promise<{ lang: string }>;
}>) {
  const { lang } = await params;
  if (!isLocalePath(lang)) notFound();

  return <I18nProvider initialLocaleTag={localePathToTag(lang)}>{children}</I18nProvider>;
}
