'use client';

import { memo } from 'react';
import { Loader2, Copy, Trash2, SquareCheck } from 'lucide-react';
import type { ChatMessage, LocalStatus } from '@/lib/api';
import { getFileCategory, formatFileSize } from '@/lib/fileUtils';
import { FileIcon } from './FileIcon';
import { FileCard } from './FileCard';
import { TransferChannelBadge } from './TransferChannelBadge';
import { ImagePreview } from './ImagePreview';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { useI18n } from '@/contexts/I18nContext';
import { filePayloadTransferChannel } from '@/lib/filePayload';

type FilePayload = {
  key?: string;
  fileName?: string;
  size?: number;
  lan?: boolean;
  webrtc?: boolean;
  /** LAN multicast send — treat as LAN when `lan` flag missing from payload */
  targetDeviceIds?: string[];
};

function StatusIndicator({ status, onRetry }: { status?: LocalStatus; onRetry?: () => void }) {
  const { t } = useI18n();
  if (status === 'sending') {
    return (
      <span className="inline-flex items-center gap-1 text-[11px] text-muted-foreground mt-1">
        <Loader2 className="w-3 h-3 animate-spin" />
        {t('chat.bubble.sending')}
      </span>
    );
  }
  if (status === 'failed') {
    return (
      <span className="inline-flex items-center gap-1.5 text-[11px] text-destructive mt-1">
        {t('chat.bubble.sendFailed')}
        {onRetry && (
          <button data-no-select-toggle type="button" onClick={onRetry} className="underline underline-offset-2 hover:no-underline">
            {t('chat.bubble.retry')}
          </button>
        )}
      </span>
    );
  }
  return null;
}

function HoverActions({
  isText,
  text,
  onDelete,
  onEnterMultiSelect,
}: {
  isText: boolean;
  text?: string;
  onDelete?: () => void;
  /** 与 Flutter PC 一致：悬停条第一项进入多选并选中本条 */
  onEnterMultiSelect?: () => void;
}) {
  const { t } = useI18n();
  return (
    <div
      data-no-select-toggle
      className="absolute bottom-1 left-1/2 z-10 flex -translate-x-1/2 items-center gap-0.5 rounded-lg border border-border/70 bg-popover/95 px-0.5 py-0.5 opacity-0 shadow-md backdrop-blur-md transition-opacity duration-200 group-hover:opacity-100"
    >
      {onEnterMultiSelect && (
        <button
          type="button"
          className="p-1 rounded hover:bg-accent/10 transition-colors text-muted-foreground hover:text-foreground"
          title={t('chat.bubble.multiSelect')}
          onClick={(e) => {
            e.stopPropagation();
            onEnterMultiSelect();
          }}
        >
          <SquareCheck className="w-3.5 h-3.5" />
        </button>
      )}
      {isText && text && (
        <button
          type="button"
          className="p-1 rounded hover:bg-accent/10 transition-colors text-muted-foreground hover:text-foreground"
          title={t('chat.bubble.copyText')}
          onClick={(e) => { e.stopPropagation(); navigator.clipboard.writeText(text); }}
        >
          <Copy className="w-3.5 h-3.5" />
        </button>
      )}
      {onDelete && (
        <button
          type="button"
          className="p-1 rounded hover:bg-destructive/10 transition-colors text-muted-foreground hover:text-destructive"
          title={t('chat.bubble.delete')}
          onClick={(e) => { e.stopPropagation(); onDelete(); }}
        >
          <Trash2 className="w-3.5 h-3.5" />
        </button>
      )}
    </div>
  );
}

export type MessageBubbleProps = {
  msg: ChatMessage;
  /** 不传则按原逻辑：系统 / 完整设备 ID（已取消截断） */
  senderLabel?: string;
  isOwn: boolean;
  onRetry?: () => void;
  onCancel?: () => void;
  onDelete?: () => void;
  /** 多选模式下隐藏单条悬停操作，避免与多选交互冲突 */
  selectMode?: boolean;
  /** 悬停「多选」入口（传输中不传，与 Flutter PC 一致） */
  onEnterMultiSelect?: () => void;
};

function messageBubbleDataEqual(a: ChatMessage, b: ChatMessage): boolean {
  if (a === b) return true;
  if (a.type !== b.type || a.ts !== b.ts || a.fromDeviceId !== b.fromDeviceId) return false;
  if (a._localId !== b._localId || a.id !== b.id) return false;
  if (a._status !== b._status || a._progress !== b._progress || a._speed !== b._speed) return false;
  return a.payload === b.payload;
}

function MessageBubbleInner({
  msg,
  senderLabel,
  isOwn,
  onRetry,
  onCancel,
  onDelete,
  selectMode,
  onEnterMultiSelect,
}: MessageBubbleProps) {
  const { t } = useI18n();
  const payload = msg.payload as { text?: string };
  const fromLabel =
    senderLabel ?? (msg.fromDeviceId === 'system' ? t('common.system') : msg.fromDeviceId);
  const status: LocalStatus | undefined = msg._status;
  const progress = msg._progress;
  const speed = msg._speed;

  // ── text message ──
  if (msg.type === 'text') {
    return (
      <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
        <div className="max-w-[65%] flex flex-col">
          {!isOwn && <span className="text-[11px] text-muted-foreground mb-0.5 ml-2">{fromLabel}</span>}
          <div
            className={`group relative rounded-2xl px-3 py-2 shadow-sm ring-1 ring-foreground/4 ${
              isOwn
                ? 'rounded-br-md bg-bubble-own'
                : 'rounded-bl-md border border-border/50 bg-card/90 backdrop-blur-[2px]'
            }`}
          >
            <p className="text-sm leading-relaxed whitespace-pre-wrap wrap-break-word select-text">{payload?.text ?? ''}</p>
            {!selectMode && (
              <HoverActions
                isText
                text={payload?.text}
                onDelete={onDelete}
                onEnterMultiSelect={onEnterMultiSelect}
              />
            )}
          </div>
          {isOwn && <div className="flex justify-end mr-1"><StatusIndicator status={status} onRetry={onRetry} /></div>}
        </div>
      </div>
    );
  }

  // ── file message ──
  if (msg.type === 'file') {
    const fp = payload as FilePayload;
    const isTransferring = status === 'uploading' || status === 'downloading';
    const category = getFileCategory(fp?.fileName);
    const progressLabel = status === 'downloading' ? t('chat.bubble.receiving') : t('chat.bubble.transferSending');
    const channel = filePayloadTransferChannel(fp);
    const showByteRow = fp?.size != null && fp.size > 0;
    const doneBytes =
      showByteRow && progress != null ? Math.round((fp.size! * progress) / 100) : null;

    // transferring state
    if (isTransferring && progress != null) {
      return (
        <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
          <div className="max-w-[70%] flex flex-col">
            {!isOwn && <span className="text-[11px] text-muted-foreground mb-0.5 ml-2">{fromLabel}</span>}
            <div className="flex items-start gap-3 rounded-2xl border border-border/60 bg-card/90 px-3.5 py-3 shadow-sm ring-1 ring-foreground/3 backdrop-blur-[2px]">
              <div className="shrink-0 mt-0.5"><FileIcon category={category} size={32} /></div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start gap-2 min-w-0">
                  <p className="text-sm font-medium truncate flex-1">{fp?.fileName ?? t('chat.bubble.fileFallback')}</p>
                  <div className="flex shrink-0 items-center gap-1.5">
                    <TransferChannelBadge transferType={channel} />
                    {!showByteRow && (
                      <span className="text-xs font-semibold tabular-nums text-primary">{progress}%</span>
                    )}
                  </div>
                </div>
                <p className="text-[11px] text-muted-foreground mt-0.5">
                  {progressLabel}
                  {!showByteRow && fp?.size != null && ` · ${formatFileSize(fp.size)}`}
                </p>
                <Progress value={progress} className="mt-2 h-1.5" />
                {(showByteRow || speed) && (
                  <div className="flex w-full items-start gap-2 mt-1 text-[11px] text-muted-foreground">
                    <span className="min-w-0 flex-1 truncate">
                      {showByteRow && doneBytes != null && fp.size != null
                        ? `${formatFileSize(doneBytes)} / ${formatFileSize(fp.size)}`
                        : ''}
                    </span>
                    {speed ? (
                      <span className="shrink-0 whitespace-nowrap text-right tabular-nums">{speed}</span>
                    ) : null}
                  </div>
                )}
                {onCancel && (
                  <div className="flex justify-end mt-1">
                    <Button data-no-select-toggle variant="link" size="sm" onClick={onCancel} className="h-auto p-0 text-[11px] text-destructive">
                      {t('chat.bubble.cancel')}
                    </Button>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      );
    }

    // sending / cancelled / failed
    if (status === 'sending' || status === 'cancelled' || status === 'failed') {
      return (
        <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
          <div className="max-w-[70%]">
            <div
              className={`flex items-center gap-3 rounded-2xl border border-border/60 bg-card/90 px-3.5 py-3 shadow-sm ring-1 ring-foreground/3 backdrop-blur-[2px] ${
              status === 'cancelled' ? 'opacity-50' : ''
            } ${status === 'failed' ? 'border-destructive/30' : ''}`}>
              <FileIcon category={category} size={32} />
              <div className="min-w-0 flex-1">
                <p className={`text-sm truncate ${status === 'failed' ? 'text-destructive' : ''}`}>{fp?.fileName ?? t('chat.bubble.fileFallback')}</p>
                <span className="text-[11px] text-muted-foreground">
                  {status === 'sending' && t('chat.bubble.sendingEllipsis')}
                  {status === 'cancelled' && t('chat.bubble.cancelled')}
                  {status === 'failed' && (
                    <>
                      {t('chat.bubble.sendFailed')}
                      {onRetry && (
                        <button data-no-select-toggle type="button" onClick={onRetry} className="ml-2 underline underline-offset-2 text-primary hover:no-underline">
                          {t('chat.bubble.retry')}
                        </button>
                      )}
                    </>
                  )}
                </span>
              </div>
            </div>
          </div>
        </div>
      );
    }

    // image message
    if (category === 'image' && fp?.key) {
      return (
        <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
          <div className="max-w-[65%] flex flex-col">
            {!isOwn && <span className="text-[11px] text-muted-foreground mb-0.5 ml-2">{fromLabel}</span>}
            <div className="relative group">
              <ImagePreview s3Key={fp.key} fileName={fp.fileName} size={fp.size} selectMode={selectMode} />
              {!selectMode && (
                <HoverActions isText={false} onDelete={onDelete} onEnterMultiSelect={onEnterMultiSelect} />
              )}
            </div>
          </div>
        </div>
      );
    }

    // completed file (S3 / LAN / WebRTC)
    return (
      <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
        <div className="max-w-[70%] flex flex-col">
          {!isOwn && <span className="text-[11px] text-muted-foreground mb-0.5 ml-2">{fromLabel}</span>}
          <div className="relative group">
            <FileCard
              fileName={fp?.fileName}
              s3Key={fp?.key}
              size={fp?.size}
              transferType={filePayloadTransferChannel(fp)}
            />
            {!selectMode && (
              <HoverActions isText={false} onDelete={onDelete} onEnterMultiSelect={onEnterMultiSelect} />
            )}
          </div>
        </div>
      </div>
    );
  }

  // ── unknown message type ──
  return (
    <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
      <div className="max-w-[65%] rounded-2xl bg-muted/80 px-3 py-2 ring-1 ring-border/40">
        <p className="text-[11px] text-muted-foreground">{fromLabel}</p>
        <p className="text-sm text-muted-foreground">{t('common.unknownMessage')}</p>
      </div>
    </div>
  );
}

const MessageBubbleMemo = memo(MessageBubbleInner, (prev, next) => {
  if (prev.isOwn !== next.isOwn || prev.selectMode !== next.selectMode) return false;
  if (prev.senderLabel !== next.senderLabel) return false;
  if (!messageBubbleDataEqual(prev.msg, next.msg)) return false;
  return true;
});

export function MessageBubble(props: MessageBubbleProps) {
  const { localeTag } = useI18n();
  return <MessageBubbleMemo key={localeTag} {...props} />;
}
