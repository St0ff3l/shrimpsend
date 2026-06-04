'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useI18n } from '@/contexts/I18nContext';
import { localizedDocsHref, localeTagToPath } from '@/lib/i18nRouting';
import { buttonVariants } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { readCookieConsent, writeCookieConsent } from '@/lib/privacyConsent';
import { Cookie } from 'lucide-react';

export function CookieConsentDialog() {
  const { localeTag, t } = useI18n();
  const [visible, setVisible] = useState(false);
  const [preferencesOpen, setPreferencesOpen] = useState(false);
  const [analyticsEnabled, setAnalyticsEnabled] = useState(true);

  useEffect(() => {
    queueMicrotask(() => {
      setVisible(readCookieConsent() === null);
    });
  }, []);

  const closeWithConsent = (analytics: boolean) => {
    writeCookieConsent(analytics ? 'all' : 'necessary');
    setVisible(false);
  };

  if (!visible) return null;

  return (
    <div className="fixed inset-x-0 bottom-3 z-50 flex max-w-[100vw] justify-center overflow-x-clip px-3 sm:bottom-5 sm:justify-end sm:px-6">
      <section className="relative w-full min-w-0 max-w-[calc(100vw-1.5rem)] overflow-hidden rounded-3xl border border-white/10 bg-background/82 p-3 shadow-xl shadow-black/20 ring-1 ring-white/[0.06] backdrop-blur-2xl sm:max-w-2xl sm:p-4">
        <div
          className="pointer-events-none absolute -top-16 right-0 size-36 rounded-full bg-primary/10 blur-3xl"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute inset-x-4 bottom-0 h-px bg-gradient-to-r from-transparent via-primary/25 to-transparent sm:inset-x-10"
          aria-hidden
        />
        <div className="relative flex flex-col gap-3">
          <div className="flex items-start gap-3">
            <span className="flex size-8 shrink-0 items-center justify-center rounded-2xl bg-primary/10 text-primary ring-1 ring-primary/18">
              <Cookie className="size-4" aria-hidden />
            </span>
            <div className="min-w-0 flex-1">
              <h2 className="font-display text-sm font-semibold tracking-tight text-foreground sm:text-base">
                {t('cookieConsent.title')}
              </h2>
              <p className="mt-1 text-xs leading-5 text-muted-foreground sm:text-sm">
                {t('cookieConsent.body')}
              </p>
              <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1.5 text-xs sm:text-sm">
                <Link
                  href={localizedDocsHref(localeTagToPath(localeTag), 'privacy')}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-medium text-primary underline-offset-4 transition-colors hover:text-foreground hover:underline"
                >
                  {t('cookieConsent.privacy')}
                </Link>
                <Link
                  href={localizedDocsHref(localeTagToPath(localeTag), 'terms')}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-medium text-primary underline-offset-4 transition-colors hover:text-foreground hover:underline"
                >
                  {t('cookieConsent.terms')}
                </Link>
              </div>
            </div>
          </div>

          {preferencesOpen ? (
            <div className="rounded-2xl border border-white/10 bg-white/[0.035] p-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-semibold text-foreground">{t('cookieConsent.necessaryLabel')}</p>
                  <p className="mt-1 text-xs leading-5 text-muted-foreground">{t('cookieConsent.necessaryDesc')}</p>
                </div>
                <span className="rounded-full bg-primary/12 px-2 py-1 text-[11px] font-medium text-primary">
                  {t('cookieConsent.alwaysOn')}
                </span>
              </div>
              <label className="mt-3 flex cursor-pointer items-start gap-3 rounded-xl p-2 transition-colors hover:bg-white/[0.04]">
                <input
                  type="checkbox"
                  checked={analyticsEnabled}
                  onChange={(event) => setAnalyticsEnabled(event.target.checked)}
                  className="mt-0.5 size-4 accent-primary"
                />
                <span>
                  <span className="block text-xs font-semibold text-foreground">{t('cookieConsent.analyticsLabel')}</span>
                  <span className="mt-1 block text-xs leading-5 text-muted-foreground">{t('cookieConsent.analyticsDesc')}</span>
                </span>
              </label>
            </div>
          ) : null}

          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-end">
            <button
              type="button"
              onClick={() => closeWithConsent(false)}
              className={cn(
                buttonVariants({ variant: 'ghost', size: 'lg' }),
                'h-9 rounded-2xl px-4',
              )}
            >
              {t('cookieConsent.rejectOptional')}
            </button>
            <button
              type="button"
              onClick={() => setPreferencesOpen((value) => !value)}
              className={cn(
                buttonVariants({ variant: 'outline', size: 'lg' }),
                'h-9 rounded-2xl bg-white/[0.04] px-4',
              )}
            >
              {preferencesOpen ? t('cookieConsent.hidePreferences') : t('cookieConsent.manage')}
            </button>
            <button
              type="button"
              onClick={() => closeWithConsent(preferencesOpen ? analyticsEnabled : true)}
              className={cn(
                buttonVariants({ size: 'lg' }),
                'h-9 rounded-2xl px-4 shadow-sm shadow-primary/10',
              )}
            >
              {preferencesOpen ? t('cookieConsent.save') : t('cookieConsent.acceptAll')}
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}
