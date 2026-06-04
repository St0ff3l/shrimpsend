import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { LegalMarkdown } from '@/components/legal/legal-markdown';
import { readLegalMarkdown } from '@/lib/legalDocs';
import { isLocalePath, type LocalePath } from '@/lib/i18nRouting';
import { publicMetadata } from '@/lib/seo';

const allowed = new Set(['en', 'zh']);
const descriptions: Record<LocalePath, string> = {
  zh: '了解 ShrimpSend 如何收集、使用和保护账号、设备、消息与文件传输相关数据。',
  en: 'Learn how ShrimpSend collects, uses, and protects account, device, message, and file transfer data.',
};

export function generateStaticParams() {
  return [{ lang: 'en' }, { lang: 'zh' }];
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ lang: string }>;
}): Promise<Metadata> {
  const { lang } = await params;
  if (!isLocalePath(lang)) return {};
  return publicMetadata({
    title: lang === 'en' ? 'Privacy Policy - ShrimpSend' : '隐私政策 - ShrimpSend',
    description: descriptions[lang],
    path: `/legal/intl/${lang}/privacy`,
    locale: lang,
    type: 'article',
  });
}

export default async function LegalIntlPrivacyPage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!allowed.has(lang)) notFound();
  const file = lang === 'en' ? 'privacy-policy.en.md' : 'privacy-policy.zh.md';
  const source = readLegalMarkdown('intl', file);
  return <LegalMarkdown source={source} />;
}
