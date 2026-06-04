'use client';

import { useI18n } from '@/contexts/I18nContext';
import { useState } from 'react';
import { downloadS3FileAsBrowserSave } from '@/lib/downloadS3File';
import { getFileCategory, formatFileSize } from '@/lib/fileUtils';
import { RefreshCw, Download } from 'lucide-react';
import { FileIcon } from './FileIcon';
import { TransferChannelBadge } from './TransferChannelBadge';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';

type Props = {
  fileName?: string;
  s3Key?: string;
  size?: number;
  /** lan | webrtc | s3 — shown as pill next to the title */
  transferType?: string;
};

export function FileCard({ fileName, s3Key, size, transferType }: Props) {
  const { t } = useI18n();
  const [downloading, setDownloading] = useState(false);
  const [progress, setProgress] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const category = getFileCategory(fileName);
  const sizeStr = formatFileSize(size);

  const handleDownload = async () => {
    if (!s3Key) return;
    setError(null);
    setDownloading(true);
    setProgress(0);
    try {
      await downloadS3FileAsBrowserSave(s3Key, fileName || 'download', (received, total) => {
        const pct = total > 0 ? Math.round((received / total) * 100) : 100;
        setProgress(pct);
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : t('fileCard.receiveFailed'));
    } finally {
      setDownloading(false);
      setProgress(null);
    }
  };

  const showProgress = downloading && progress != null;

  return (
    <div className="flex items-center gap-3 rounded-xl border bg-card shadow-sm px-3.5 py-3 min-w-[220px] max-w-full transition-shadow hover:shadow-md">
      <div className="shrink-0">
        <FileIcon category={category} size={36} />
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-start gap-2 min-w-0">
          <p className="text-sm font-medium truncate text-foreground flex-1">{fileName || t('chat.bubble.fileFallback')}</p>
          <TransferChannelBadge transferType={transferType} />
        </div>
        <div className="flex items-center gap-2 mt-0.5">
          {sizeStr && <span className="text-[11px] text-muted-foreground">{sizeStr}</span>}
          {error && <span className="text-[11px] text-destructive">{error}</span>}
        </div>
        {showProgress && (
          <div className="mt-2">
            <Progress value={progress} className="h-1" />
            <p className="text-[11px] text-muted-foreground mt-0.5">{t('fileCard.receivingPct', { percent: progress ?? 0 })}</p>
          </div>
        )}
      </div>

      {s3Key && !showProgress && (
        <Button
          variant="outline"
          size="icon"
          onClick={handleDownload}
          disabled={downloading}
          className="shrink-0 rounded-full w-8 h-8"
          title={downloading ? t('fileCard.downloadingTitle') : error ? t('fileCard.retryTitle') : t('fileCard.downloadTitle')}
        >
          {downloading ? (
            <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
          ) : error ? (
            <RefreshCw className="w-4 h-4" />
          ) : (
            <Download className="w-4 h-4" />
          )}
        </Button>
      )}
    </div>
  );
}
