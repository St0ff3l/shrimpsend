'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { Copy, ExternalLink } from 'lucide-react';
import { useI18n } from '@/contexts/I18nContext';
import { localizedDocsHref, localeTagToPath } from '@/lib/i18nRouting';
import { Button, buttonVariants } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  setCorsAlertListener,
  type CorsAlertPayload,
} from '@/lib/network/corsAlert';
import { logger } from '@/lib/logger';
import { cn } from '@/lib/utils';

const TAG = 'CorsAlertProvider';

export function CorsAlertProvider() {
  const { localeTag, t } = useI18n();
  const [payload, setPayload] = useState<CorsAlertPayload | null>(null);
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    setCorsAlertListener((p) => {
      logger.info(TAG, 'cors-likely failure', p.mode, p.channel, p.url);
      setPayload(p);
      setCopied(false);
      setOpen(true);
    });
    return () => setCorsAlertListener(null);
  }, []);

  const origin = typeof window !== 'undefined' ? window.location.origin : '';

  const titleKey =
    payload?.mode === 'upload'
      ? 'errors.corsLikely.titleUpload'
      : 'errors.corsLikely.titleDownload';

  const handleCopy = async () => {
    try {
      if (typeof navigator !== 'undefined' && navigator.clipboard) {
        await navigator.clipboard.writeText(origin);
        setCopied(true);
        window.setTimeout(() => setCopied(false), 1800);
      }
    } catch (e) {
      logger.warn(TAG, 'copy origin failed', e);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t(titleKey)}</DialogTitle>
          <DialogDescription>{t('errors.corsLikely.body')}</DialogDescription>
        </DialogHeader>

        <div className="space-y-2">
          <p className="text-xs text-muted-foreground">
            {t('errors.corsLikely.originLabel')}
          </p>
          <div className="flex items-center gap-2 rounded-lg border border-border/70 bg-muted/40 px-3 py-2">
            <code className="flex-1 truncate font-mono text-xs text-foreground">
              {origin || '—'}
            </code>
            <Button
              type="button"
              variant="ghost"
              size="icon-sm"
              onClick={handleCopy}
              disabled={!origin}
              title={t('errors.corsLikely.copyOrigin')}
              className="shrink-0"
            >
              <Copy className="size-3.5" aria-hidden />
            </Button>
          </div>
          {copied && (
            <p className="text-[11px] text-primary">
              {t('errors.corsLikely.copied')}
            </p>
          )}
          {payload?.url && (
            <p className="break-all text-[11px] text-muted-foreground/80">
              {t('errors.corsLikely.failedUrl')}: <span className="font-mono">{payload.url}</span>
            </p>
          )}
        </div>

        <DialogFooter className="sm:justify-between">
          <Button variant="ghost" onClick={() => setOpen(false)} type="button">
            {t('errors.corsLikely.dismiss')}
          </Button>
          <Link
            href={localizedDocsHref(localeTagToPath(localeTag), 's3')}
            target="_blank"
            rel="noopener noreferrer"
            className={cn(buttonVariants({ size: 'default' }), 'gap-1.5')}
          >
            <ExternalLink className="size-3.5" aria-hidden />
            {t('errors.corsLikely.viewDocs')}
          </Link>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
