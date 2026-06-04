'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';
import { useMinWidthMd } from '@/hooks/useMediaQuery';
import { S3Panel } from '@/components/settings';

export default function S3SettingsPage() {
  const { t } = useI18n();
  const isWide = useMinWidthMd();

  return (
    <div className="min-h-dvh animate-app-fade-in p-4 text-foreground md:min-h-0 md:p-0">
      <div className="mb-6 flex items-center gap-4 md:hidden">
        <Link href="/settings" className="text-muted-foreground transition-colors hover:text-foreground">
          ← {t('common.back')}
        </Link>
        <h1 className="font-display text-xl font-semibold tracking-tight">{t('settings.s3PageTitle')}</h1>
      </div>
      <div className="mx-auto max-w-lg space-y-4 md:mx-0 md:max-w-2xl">
        <h2 className="font-display hidden text-base font-semibold tracking-tight md:block">{t('settings.s3PageTitle')}</h2>
        <S3Panel idPrefix={isWide ? 'settings-wide-s3' : 'settings-s3-narrow'} wrapInCard={!isWide} />
      </div>
    </div>
  );
}
