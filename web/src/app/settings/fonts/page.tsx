'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';
import { FontsPanel, SettingsSectionTitle } from '@/components/settings';

export default function FontsSettingsPage() {
  const { t } = useI18n();
  return (
    <div className="min-h-dvh animate-app-fade-in p-4 text-foreground md:min-h-0 md:p-0">
      <div className="mb-6 flex items-center gap-4 md:hidden">
        <Link href="/settings" className="text-muted-foreground transition-colors hover:text-foreground">
          ← {t('common.back')}
        </Link>
        <h1 className="font-display text-xl font-semibold tracking-tight">{t('settings.fontsPageTitle')}</h1>
      </div>
      <div className="space-y-3">
        <div className="hidden md:block">
          <SettingsSectionTitle title={t('settings.fontsPageTitle')} />
        </div>
        <FontsPanel />
      </div>
    </div>
  );
}
