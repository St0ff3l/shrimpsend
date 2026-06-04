'use client';

import { useCallback, useEffect, useState } from 'react';
import { ImageOff } from 'lucide-react';
import { resolveDownloadUrl } from '@/lib/services/s3Transfer';
import { formatFileSize } from '@/lib/fileUtils';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { Skeleton } from '@/components/ui/skeleton';
import { useI18n } from '@/contexts/I18nContext';

type Props = {
  s3Key: string;
  fileName?: string;
  size?: number;
  /** 多选模式下点击图片不打开灯箱，事件交给外层用于勾选 */
  selectMode?: boolean;
};

export function ImagePreview({ s3Key, fileName, size, selectMode }: Props) {
  const { t } = useI18n();
  const [src, setSrc] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [lightbox, setLightbox] = useState(false);

  useEffect(() => {
    let cancelled = false;
    resolveDownloadUrl(s3Key)
      .then((url) => {
        if (!cancelled) setSrc(url);
      })
      .catch(() => {
        if (!cancelled) {
          setError(true);
          setLoading(false);
        }
      });
    return () => { cancelled = true; };
  }, [s3Key]);

  const handleLoad = useCallback(() => setLoading(false), []);
  const handleError = useCallback(() => {
    setError(true);
    setLoading(false);
  }, []);

  if (error) {
    return (
      <div className="flex items-center gap-2 rounded-xl border bg-card px-3 py-2.5 text-sm text-muted-foreground">
        <ImageOff className="w-5 h-5 shrink-0 opacity-40" />
        <span className="truncate">{fileName || t('image.fallback')}</span>
        <span className="text-[11px] text-destructive shrink-0">{t('image.loadFailed')}</span>
      </div>
    );
  }

  return (
    <>
      <div className="inline-block">
        {loading && <Skeleton className="w-[180px] h-[120px] rounded-xl" />}
        {src && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={src}
            alt={fileName || t('image.fallback')}
            onLoad={handleLoad}
            onError={handleError}
            onClick={() => {
              if (selectMode) return;
              setLightbox(true);
            }}
            className={`rounded-xl max-w-[220px] max-h-[180px] object-cover cursor-pointer hover:brightness-95 transition-all ${
              loading ? 'opacity-0 absolute w-0 h-0' : 'opacity-100'
            }`}
          />
        )}
        {!loading && (
          <p className="text-[11px] text-muted-foreground mt-1 px-0.5 truncate max-w-[220px]">
            {fileName}{size != null && <span className="ml-1">· {formatFileSize(size)}</span>}
          </p>
        )}
      </div>

      <Dialog open={lightbox} onOpenChange={setLightbox}>
        <DialogContent className="max-w-[90vw] max-h-[90vh] p-1 border-none bg-black/90 shadow-2xl">
          {src && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={src}
              alt={fileName || t('image.fallback')}
              className="max-w-full max-h-[85vh] object-contain rounded-lg mx-auto"
            />
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
