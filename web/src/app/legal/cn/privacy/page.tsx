import { LegalMarkdown } from '@/components/legal/legal-markdown';
import { readLegalMarkdown } from '@/lib/legalDocs';
import { publicMetadata } from '@/lib/seo';

export const metadata = publicMetadata({
  title: '隐私政策 - 虾传',
  description: '了解虾传如何收集、使用和保护账号、设备、消息与文件传输相关数据。',
  path: '/legal/cn/privacy',
  locale: 'zh',
  type: 'article',
});

export default function LegalCnPrivacyPage() {
  const source = readLegalMarkdown('cn-mainland', 'privacy-policy.md');
  return <LegalMarkdown source={source} />;
}
