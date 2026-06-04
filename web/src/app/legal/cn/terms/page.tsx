import { LegalMarkdown } from '@/components/legal/legal-markdown';
import { readLegalMarkdown } from '@/lib/legalDocs';
import { publicMetadata } from '@/lib/seo';

export const metadata = publicMetadata({
  title: '用户服务协议 - 虾传',
  description: '阅读虾传用户服务协议，了解账号、会员、文件传输、S3 配置和服务使用规则。',
  path: '/legal/cn/terms',
  locale: 'zh',
  type: 'article',
});

export default function LegalCnTermsPage() {
  const source = readLegalMarkdown('cn-mainland', 'terms-of-service.md');
  return <LegalMarkdown source={source} />;
}
