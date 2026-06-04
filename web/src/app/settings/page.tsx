'use client';

import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { useMinWidthMd } from '@/hooks/useMediaQuery';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { getS3Config, type S3StorageMode } from '@/lib/api';
import { logger } from '@/lib/logger';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { Globe, Keyboard, Type, User } from 'lucide-react';

const TAG = 'settings';

function SectionTitle({ title }: { title: string }) {
  return (
    <h2 className="mb-2 px-1 text-xs font-medium uppercase tracking-wider text-muted-foreground">{title}</h2>
  );
}

export default function SettingsPage() {
  const { t } = useI18n();
  const { logout } = useAuth();
  const router = useRouter();
  const isWide = useMinWidthMd();
  const [s3Mode, setS3Mode] = useState<S3StorageMode | null>(null);

  useEffect(() => {
    getS3Config()
      .then((data) => {
        logger.info(TAG, 'S3 mode=', data.mode);
        setS3Mode(data.mode);
      })
      .catch(() => setS3Mode('DISABLED'));
  }, []);

  useEffect(() => {
    if (isWide) {
      router.replace('/settings/account');
    }
  }, [isWide, router]);

  const handleLogout = async () => {
    await logout();
    router.push('/login');
  };

  if (isWide) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-3 text-muted-foreground animate-app-fade-in">
        <div
          className="size-8 shrink-0 rounded-full border-2 border-primary/25 border-t-primary motion-safe:animate-spin"
          aria-hidden
        />
        <span className="text-sm">{t('common.loading')}</span>
      </div>
    );
  }

  return (
    <div className="min-h-dvh p-4 text-foreground animate-app-fade-in">
      <div className="mx-auto max-w-lg">
        <div className="mb-6 flex items-center gap-4">
          <Link href="/chat" className="text-muted-foreground transition-colors hover:text-foreground">
            ← {t('common.back')}
          </Link>
          <h1 className="font-display text-xl font-semibold tracking-tight">{t('settings.title')}</h1>
        </div>

        <SectionTitle title={t('settings.sectionAccount')} />
        <Card className="mb-5">
          <Link
            href="/settings/account"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/12 text-primary">
                <User className="size-4" />
              </span>
              <div>
                <p className="text-sm font-medium">{t('settings.navAccount')}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">{t('settings.accountSubtitle')}</p>
              </div>
            </div>
            <span className="text-sm text-muted-foreground">›</span>
          </Link>
        </Card>

        <SectionTitle title={t('settings.sectionGeneral')} />
        <Card className="mb-5">
          <Link
            href="/settings/language"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-100 text-emerald-700 dark:bg-emerald-900/35 dark:text-emerald-400">
                <Globe className="size-4" />
              </span>
              <div>
                <p className="text-sm font-medium">{t('settings.navLanguage')}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">{t('settings.languageSubtitle')}</p>
              </div>
            </div>
            <span className="text-sm text-muted-foreground">›</span>
          </Link>
        </Card>

        <SectionTitle title={t('settings.sectionFeatures')} />
        <Card className="mb-5">
          <Link
            href="/settings/membership"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-amber-100 text-base text-amber-600 dark:bg-amber-900/40 dark:text-amber-400">
                ★
              </span>
              <div>
                <p className="text-sm font-medium">{t('settings.navMembership')}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">{t('settings.membershipSubtitle')}</p>
              </div>
            </div>
            <span className="text-sm text-muted-foreground">›</span>
          </Link>
          <Separator />
          <Link
            href="/settings/s3"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-100 text-base text-blue-600 dark:bg-blue-900/40 dark:text-blue-400">
                ☁
              </span>
              <div>
                <p className="text-sm font-medium">{t('settings.navS3')}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">{t('settings.s3RowSubtitle')}</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {s3Mode !== null && (
                <Badge variant={s3Mode === 'DISABLED' ? 'secondary' : 'default'}>
                  {s3Mode === 'CUSTOM'
                    ? t('settings.s3StatusCustom')
                    : s3Mode === 'HOSTED'
                      ? t('settings.s3StatusHosted')
                      : t('settings.s3StatusOff')}
                </Badge>
              )}
              <span className="text-sm text-muted-foreground">›</span>
            </div>
          </Link>
        </Card>

        <SectionTitle title={t('settings.navAppearance')} />
        <Card className="mb-5">
          <Link
            href="/settings/appearance"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex flex-col gap-0.5">
              <span className="text-sm font-medium">{t('settings.navAppearance')}</span>
              <p className="mt-0.5 text-xs text-muted-foreground">{t('settings.appearanceSubtitle')}</p>
            </div>
            <span className="text-sm text-muted-foreground">›</span>
          </Link>
          <Separator />
          <Link
            href="/settings/fonts"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-sky-100 text-sky-700 dark:bg-sky-900/35 dark:text-sky-400">
                <Type className="size-4" />
              </span>
              <div>
                <p className="text-sm font-medium">{t('settings.navFonts')}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">{t('settings.fontsSubtitle')}</p>
              </div>
            </div>
            <span className="text-sm text-muted-foreground">›</span>
          </Link>
          <Separator />
          <Link
            href="/settings/shortcuts"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-violet-100 text-violet-700 dark:bg-violet-900/35 dark:text-violet-400">
                <Keyboard className="size-4" />
              </span>
              <div>
                <p className="text-sm font-medium">{t('settings.navShortcuts')}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">{t('settings.shortcutsSubtitle')}</p>
              </div>
            </div>
            <span className="text-sm text-muted-foreground">›</span>
          </Link>
        </Card>

        <SectionTitle title={t('settings.navAbout')} />
        <Card className="mb-5">
          <Link
            href="/settings/about"
            className="flex items-center justify-between rounded-xl px-4 py-3.5 transition-colors duration-150 hover:bg-muted/60"
          >
            <div className="flex flex-col gap-0.5">
              <span className="text-sm font-medium">{t('settings.navAbout')}</span>
              <span className="text-xs text-muted-foreground">{t('settings.aboutSubtitle')}</span>
            </div>
            <span className="text-sm text-muted-foreground">›</span>
          </Link>
        </Card>

        <div className="mt-6">
          <Button variant="destructive" className="w-full" onClick={handleLogout}>
            {t('settings.logout')}
          </Button>
        </div>
      </div>
    </div>
  );
}
