'use client';

import { useI18n } from '@/contexts/I18nContext';
import { useState } from 'react';
import { S3TransferService } from '@/lib/services/s3Transfer';
import type { CloudTransferService } from '@/lib/services/cloudTransfer';
import { formatFileSize } from '@/lib/fileUtils';

const cloudTransfer: CloudTransferService = new S3TransferService();

/**
 * @deprecated Use FileCard instead. Kept for backward compatibility.
 */
export function FileDownload({ name, key_, size }: { name?: string; key_?: string; size?: number }) {
  const { t } = useI18n();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [downloadProgress, setDownloadProgress] = useState<number | null>(null);
  const handleDownload = async () => {
    if (!key_) return;
    setError(null);
    setLoading(true);
    setDownloadProgress(0);
    try {
      const result = await cloudTransfer.download(key_, (received, total) => {
        const pct = total > 0 ? Math.round((received / total) * 100) : 100;
        setDownloadProgress(pct);
      });
      const blobUrl = URL.createObjectURL(result.blob);
      const a = document.createElement('a');
      a.href = blobUrl;
      a.download = name || 'download';
      a.click();
      URL.revokeObjectURL(blobUrl);
    } catch (e) {
      setError(e instanceof Error ? e.message : t('fileCard.receiveFailed'));
    } finally {
      setLoading(false);
      setDownloadProgress(null);
    }
  };
  const sizeStr = formatFileSize(size);
  const showProgress = loading && downloadProgress != null;
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-2">
        <span className="text-sm truncate">{name || t('chat.bubble.fileFallback')}</span>
        {sizeStr && <span className="text-xs text-zinc-500">{sizeStr}</span>}
        {key_ && !showProgress && (
          <button
            type="button"
            onClick={handleDownload}
            disabled={loading}
            className="text-sm text-emerald-400 hover:text-emerald-300 disabled:opacity-50"
          >
            {loading ? t('fileDownload.ellipsis') : error ? t('fileCard.retryTitle') : t('fileDownload.receive')}
          </button>
        )}
      </div>
      {showProgress && (
        <>
          <div className="mt-1 h-1.5 w-full rounded-full bg-zinc-700 overflow-hidden">
            <div className="h-full bg-emerald-500 rounded-full transition-all" style={{ width: `${downloadProgress ?? 0}%` }} />
          </div>
          <p className="text-xs text-zinc-400 mt-0.5">{t('fileCard.receivingPct', { percent: downloadProgress ?? 0 })}</p>
        </>
      )}
      {error && <span className="text-xs text-red-400">{error}</span>}
    </div>
  );
}
