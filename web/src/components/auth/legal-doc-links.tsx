'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useI18n } from '@/contexts/I18nContext';
import {
  LOCALE_REGION_PREFS_CHANGED_EVENT,
  getStoredLocaleTag,
} from '@/lib/localeRegionPreferences';
import { localizedDocsHref, localeTagToPath } from '@/lib/i18nRouting';
import { cn } from '@/lib/utils';

export type LegalDocLinksProps = {
  className?: string;
};

type LegalHrefs = { privacy: string; terms: string };

function computeHrefs(): LegalHrefs {
  const locale = localeTagToPath(getStoredLocaleTag());
  return {
    privacy: localizedDocsHref(locale, 'privacy'),
    terms: localizedDocsHref(locale, 'terms'),
  };
}

export function LegalDocLinks({ className }: LegalDocLinksProps) {
  const { t } = useI18n();
  const [href, setHref] = useState<LegalHrefs | null>(null);

  useEffect(() => {
    const sync = () => setHref(computeHrefs());
    sync();
    window.addEventListener('storage', sync);
    window.addEventListener(LOCALE_REGION_PREFS_CHANGED_EVENT, sync);
    return () => {
      window.removeEventListener('storage', sync);
      window.removeEventListener(LOCALE_REGION_PREFS_CHANGED_EVENT, sync);
    };
  }, []);

  return (
    <nav
      className={cn(
        'flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-center text-sm text-muted-foreground',
        className,
      )}
      aria-label={t('legal.docNavAria')}
    >
      {href ? (
        <Link href={href.privacy} target="_blank" rel="noopener noreferrer" className="font-medium text-primary underline-offset-4 hover:underline">
          {t('auth.legalPrivacy')}
        </Link>
      ) : (
        <span className="font-medium text-primary">{t('auth.legalPrivacy')}</span>
      )}
      <span aria-hidden className="text-muted-foreground/70">
        ·
      </span>
      {href ? (
        <Link href={href.terms} target="_blank" rel="noopener noreferrer" className="font-medium text-primary underline-offset-4 hover:underline">
          {t('auth.legalTerms')}
        </Link>
      ) : (
        <span className="font-medium text-primary">{t('auth.legalTerms')}</span>
      )}
    </nav>
  );
}
