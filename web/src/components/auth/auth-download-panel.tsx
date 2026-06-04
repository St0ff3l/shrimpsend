'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useI18n } from '@/contexts/I18nContext';
import { getClientReleaseDownloadUrl, isClientDownloadOverseas } from '@/lib/clientReleaseDownload';
import { localizedDocsHref, localeTagToPath } from '@/lib/i18nRouting';
import { cn } from '@/lib/utils';
import { buttonVariants } from '@/components/ui/button';
import { Download, ExternalLink, Globe2 } from 'lucide-react';

export function AuthDownloadPanel() {
  const { localeTag, t } = useI18n();
  const [overseas, setOverseas] = useState(() => isClientDownloadOverseas());
  const [href, setHref] = useState(() => getClientReleaseDownloadUrl());

  useEffect(() => {
    queueMicrotask(() => {
      setOverseas(isClientDownloadOverseas());
      setHref(getClientReleaseDownloadUrl());
    });
  }, []);

  return (
    <section className="mx-auto w-full max-w-2xl">
      <div className="mb-7">
        <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-primary/20 bg-primary/[0.08] px-3 py-1.5 text-xs font-medium text-primary">
          <Globe2 className="size-3.5" />
          {overseas ? t('auth.downloadRegionOverseas') : t('auth.downloadRegionMainland')}
        </div>
        <h1 className="font-display text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
          {t('auth.downloadPanelTitle')}
        </h1>
        <p className="mt-4 max-w-xl text-sm leading-7 text-muted-foreground">
          {t('auth.downloadPanelSubtitle')}
        </p>
      </div>

      <a
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className="landing-glass-card group flex items-center gap-4 rounded-3xl p-5 transition-transform hover:-translate-y-0.5"
      >
        <span className="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-primary/12 text-primary ring-1 ring-primary/20">
          <Download className="size-5" />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block text-sm font-semibold text-foreground">
            {overseas ? t('auth.downloadReleasesGithub') : t('auth.downloadReleasesGitee')}
          </span>
          <span className="mt-1 block text-xs leading-5 text-muted-foreground">{t('auth.downloadReleasesCta')}</span>
        </span>
        <ExternalLink className="size-4 shrink-0 text-primary/80 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
      </a>

      <p className="mt-3 text-xs text-muted-foreground">{t('auth.downloadPlatformsHint')}</p>

      <div className="mt-5 flex flex-wrap gap-3">
        <Link href={localizedDocsHref(localeTagToPath(localeTag), 'intro')} className={cn(buttonVariants({ variant: 'ghost' }), 'rounded-2xl text-muted-foreground')}>
          {t('landing.navDocs')}
        </Link>
      </div>
    </section>
  );
}
