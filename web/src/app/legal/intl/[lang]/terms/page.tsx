import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { LegalMarkdown } from '@/components/legal/legal-markdown';
import { readLegalMarkdown } from '@/lib/legalDocs';
import { isLocalePath, type LocalePath } from '@/lib/i18nRouting';
import { publicMetadata } from '@/lib/seo';

const allowed = new Set(['en', 'zh']);
const descriptions: Record<LocalePath, string> = {
  zh: '阅读 ShrimpSend 用户服务协议，了解账号、会员、文件传输、S3 配置和服务使用规则。',
  en: 'Read the ShrimpSend Terms of Service for account, membership, file transfer, S3, and service usage rules.',
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
    title: lang === 'en' ? 'Terms of Service - ShrimpSend' : '用户服务协议 - ShrimpSend',
    description: descriptions[lang],
    path: `/legal/intl/${lang}/terms`,
    locale: lang,
    type: 'article',
  });
}

export default async function LegalIntlTermsPage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!allowed.has(lang)) notFound();
  const file = lang === 'en' ? 'terms-of-service.en.md' : 'terms-of-service.zh.md';
  const source = readLegalMarkdown('intl', file);
  return <LegalMarkdown source={source} />;
}
