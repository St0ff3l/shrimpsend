'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';
import { DevApiEnvironmentCard } from '@/components/settings/dev-api-environment-card';
import { LocaleRegionPanel } from '@/components/settings/locale-region-panel';
import { Card, CardContent } from '@/components/ui/card';

export default function LanguageSettingsPage() {
  const { t } = useI18n();
  return (
    <div className="min-h-dvh animate-app-fade-in p-4 text-foreground md:min-h-0 md:p-0">
      <div className="mb-6 flex items-center gap-4 md:hidden">
        <Link href="/settings" className="text-muted-foreground transition-colors hover:text-foreground">
          ← {t('common.back')}
        </Link>
        <h1 className="font-display text-xl font-semibold tracking-tight">{t('settings.languagePageTitle')}</h1>
      </div>
      <div className="mx-auto max-w-2xl space-y-4 md:mx-0 md:max-w-none">
        <h2 className="font-display hidden text-base font-semibold tracking-tight md:block">{t('settings.languagePageTitle')}</h2>
        <DevApiEnvironmentCard />
        <Card>
          <CardContent className="pt-6">
            <LocaleRegionPanel />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
