'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';
import { MembershipPanel } from '@/components/settings';

export default function MembershipPage() {
  const { t } = useI18n();
  return (
    <div className="min-h-dvh animate-app-fade-in p-4 text-foreground md:min-h-0 md:p-0">
      <div className="mb-6 flex items-center gap-4 md:hidden">
        <Link href="/settings" className="text-muted-foreground transition-colors hover:text-foreground">
          ← {t('common.back')}
        </Link>
        <h1 className="font-display text-xl font-semibold tracking-tight">{t('settings.membershipPageTitle')}</h1>
      </div>
      <div className="mx-auto max-w-2xl space-y-4 md:mx-0 md:max-w-none">
        <h2 className="font-display hidden text-base font-semibold tracking-tight md:block">{t('settings.membershipPageTitle')}</h2>
        <MembershipPanel />
      </div>
    </div>
  );
}
