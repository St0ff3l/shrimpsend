'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';
import { useMinWidthMd } from '@/hooks/useMediaQuery';
import { AccountPanel } from '@/components/settings';
import { Card, CardContent } from '@/components/ui/card';

export default function AccountSettingsPage() {
  const { t } = useI18n();
  const isWide = useMinWidthMd();

  return (
    <div className="min-h-dvh animate-app-fade-in p-4 text-foreground md:min-h-0 md:p-0">
      <div className="mb-6 flex items-center gap-4 md:hidden">
        <Link href="/settings" className="text-muted-foreground transition-colors hover:text-foreground">
          ← {t('common.back')}
        </Link>
        <h1 className="font-display text-xl font-semibold tracking-tight">{t('settings.accountPageTitle')}</h1>
      </div>
      <div className="mx-auto max-w-2xl space-y-4 md:mx-0 md:max-w-none">
        <h2 className="font-display hidden text-base font-semibold tracking-tight md:block">{t('settings.accountPageTitle')}</h2>
        <Card>
          <CardContent className="pt-6">
            <AccountPanel hideLogout={isWide} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
