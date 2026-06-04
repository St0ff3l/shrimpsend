'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';
import { Download } from 'lucide-react';
import { AboutPanel, SettingsSectionTitle } from '@/components/settings';
import { buttonVariants } from '@/components/ui/button';
import { getClientReleaseDownloadUrl } from '@/lib/clientReleaseDownload';
import { cn } from '@/lib/utils';

export default function AboutSettingsPage() {
  const { t } = useI18n();
  const releaseHref = getClientReleaseDownloadUrl();

  return (
    <div className="min-h-dvh animate-app-fade-in p-4 text-foreground md:min-h-0 md:p-0">
      <div className="mb-6 flex items-center gap-4 md:hidden">
        <Link href="/settings" className="text-muted-foreground transition-colors hover:text-foreground">
          ← {t('common.back')}
        </Link>
        <h1 className="font-display text-xl font-semibold tracking-tight">{t('settings.aboutPageTitle')}</h1>
      </div>
      <div className="space-y-3">
        <div className="hidden md:block">
          <SettingsSectionTitle title={t('settings.aboutPageTitle')} />
        </div>
        <AboutPanel />
        <a
          href={releaseHref}
          target="_blank"
          rel="noopener noreferrer"
          className={cn(buttonVariants({ variant: 'outline' }), 'inline-flex w-full gap-2 md:w-auto md:min-w-[200px]')}
        >
          <Download className="h-4 w-4" />
          {t('about.getClient')}
        </a>
      </div>
    </div>
  );
}
