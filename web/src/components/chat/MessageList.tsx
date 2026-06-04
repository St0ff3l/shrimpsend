'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { useChatContext } from '@/contexts/ChatContext';
import { useI18n } from '@/contexts/I18nContext';
import { MessageBubble } from '@/components/MessageBubble';
import { senderDisplayLabel } from '@/lib/senderDisplay';
import { Button } from '@/components/ui/button';
import { getOrCreateDeviceId } from '@/lib/deviceId';
import { ChevronDown, Circle, CircleCheck, MessageCircle } from 'lucide-react';

const SCROLL_TO_BOTTOM_THRESHOLD = 120;

function getMessageSelectKey(msg: { id?: number; _localId?: string }): string | null {
  if (msg.id != null) return `id:${msg.id}`;
  if (msg._localId) return `local:${msg._localId}`;
  return null;
}

function isMessageTransferring(msg: { _status?: string; type?: string }): boolean {
  const s = msg._status;
  if (s === 'uploading' || s === 'downloading') return true;
  if (msg.type === 'file' && s === 'sending') return true;
  return false;
}

export function MessageList() {
  const { t } = useI18n();
  const {
    messages,
    devices,
    loadMoreMessages,
    loadingMore,
    selectMode,
    selectedKeys,
    toggleMessageSelect,
    enterSelectWithKey,
    handleDeleteMessage,
    cancelTransfer,
    handleRetryText,
    handleRetryFile,
  } = useChatContext();

  const listRef = useRef<HTMLDivElement>(null);
  const prevMessageCountRef = useRef(0);
  const prependingRef = useRef(false);
  const [showScrollToBottom, setShowScrollToBottom] = useState(false);

  const retryInfoRef = useChatContext() as unknown as { handleRetryFile: (id: string) => void };

  const rowVirtualizer = useVirtualizer({
    count: messages.length,
    getScrollElement: () => listRef.current,
    estimateSize: () => 104,
    overscan: 12,
    getItemKey: (index) => {
      const m = messages[index];
      if (!m) return index;
      const mid = m.id;
      return m._localId ?? `srv-${mid ?? 'noid'}-${m.ts}-${index}`;
    },
  });

  useEffect(() => {
    if (prependingRef.current) {
      prependingRef.current = false;
      requestAnimationFrame(() => {
        const el = listRef.current;
        if (!el) return;
        const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
        setShowScrollToBottom(distanceToBottom > SCROLL_TO_BOTTOM_THRESHOLD);
      });
      return;
    }
    const n = messages.length;
    const grew = n > prevMessageCountRef.current;
    prevMessageCountRef.current = n;
    if (grew) {
      listRef.current?.scrollTo(0, listRef.current.scrollHeight);
      setShowScrollToBottom(false);
    } else {
      requestAnimationFrame(() => {
        const el = listRef.current;
        if (!el) return;
        const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
        setShowScrollToBottom(distanceToBottom > SCROLL_TO_BOTTOM_THRESHOLD);
      });
    }
  }, [messages]);

  const handleListScroll = useCallback(() => {
    const el = listRef.current;
    if (!el) return;
    const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    setShowScrollToBottom(distanceToBottom > SCROLL_TO_BOTTOM_THRESHOLD);
    if (el.scrollTop < 80) {
      loadMoreMessages();
    }
  }, [loadMoreMessages]);

  const scrollToBottom = useCallback(() => {
    const el = listRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' });
    setShowScrollToBottom(false);
  }, []);

  return (
    <div ref={listRef} className="flex-1 space-y-4 overflow-y-auto p-4 sm:p-5" onScroll={handleListScroll}>
      {loadingMore && (
        <div className="flex justify-center py-2">
          <span className="text-xs text-muted-foreground">{t('chat.loadMore')}</span>
        </div>
      )}
      {messages.length === 0 && !loadingMore && (
        <div className="flex h-full select-none flex-col items-center justify-center gap-4 px-6 text-center">
          <div className="flex size-16 items-center justify-center rounded-2xl bg-muted/50 motion-safe:animate-app-fade-up">
            <MessageCircle className="size-8 text-muted-foreground/40" strokeWidth={1.15} />
          </div>
          <p className="max-w-xs text-sm leading-relaxed text-muted-foreground motion-safe:animate-app-fade-up app-stagger-1">
            {t('chat.empty.hint')}
          </p>
        </div>
      )}
      {messages.length > 0 && (
        <div className="relative w-full" style={{ height: rowVirtualizer.getTotalSize() }}>
          {rowVirtualizer.getVirtualItems().map((vi) => {
            const msg = messages[vi.index];
            if (!msg) return null;
            const selectKey = getMessageSelectKey(msg);
            const selected = selectKey != null && selectedKeys.has(selectKey);
            const transferring = isMessageTransferring(msg);
            const onEnterMultiSelect = selectKey && !transferring ? () => enterSelectWithKey(selectKey) : undefined;
            return (
              <div
                key={vi.key}
                data-index={vi.index}
                ref={rowVirtualizer.measureElement}
                className="absolute left-0 top-0 w-full px-0 pb-4"
                style={{ transform: `translateY(${vi.start}px)` }}
              >
                <div
                  className={`group -mx-1 flex items-start gap-1 rounded-xl px-1 py-0.5 transition-colors duration-150 ${
                    selectMode && selected ? 'bg-primary/12 ring-1 ring-primary/20' : ''
                  } ${selectMode && selectKey ? 'cursor-pointer hover:bg-muted/40' : ''}`}
                  onClick={(e) => {
                    if (!selectMode || !selectKey) return;
                    const el = e.target as HTMLElement;
                    if (el.closest('[data-select-checkbox], button, a, [role="button"], input, textarea, [data-no-select-toggle]')) return;
                    toggleMessageSelect(selectKey);
                  }}
                >
                  {selectMode && selectKey && (
                    <div
                      data-select-checkbox
                      className="shrink-0 w-10 pt-0.5 flex justify-center items-start"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <button
                        type="button"
                        title={selected ? t('chat.deselectToggle') : t('chat.selectToggle')}
                        className="p-0.5 rounded-full text-muted-foreground hover:text-foreground shrink-0"
                        onClick={() => toggleMessageSelect(selectKey)}
                      >
                        {selected ? (
                          <CircleCheck className="size-6 text-primary" strokeWidth={2} />
                        ) : (
                          <Circle className="size-6" strokeWidth={2} />
                        )}
                      </button>
                    </div>
                  )}
                  <div className="min-w-0 flex-1">
                    <MessageBubble
                      msg={msg}
                      senderLabel={senderDisplayLabel(msg.fromDeviceId, devices, t)}
                      isOwn={msg.fromDeviceId === getOrCreateDeviceId()}
                      selectMode={selectMode}
                      onEnterMultiSelect={onEnterMultiSelect}
                      onRetry={
                        msg._localId && msg._status === 'failed'
                          ? msg.type === 'text'
                            ? () => handleRetryText(msg._localId!)
                            : () => handleRetryFile(msg._localId!)
                          : undefined
                      }
                      onCancel={
                        msg._localId && (msg._status === 'uploading' || msg._status === 'downloading')
                          ? () => cancelTransfer(msg._localId!)
                          : undefined
                      }
                      onDelete={selectMode ? undefined : () => handleDeleteMessage(msg)}
                    />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
      {showScrollToBottom && (
        <div className="sticky bottom-3 z-20 flex justify-end pointer-events-none">
          <Button
            type="button"
            size="icon"
            onClick={scrollToBottom}
            className="pointer-events-auto rounded-full shadow-lg"
            title={t('chat.scrollBottom')}
          >
            <ChevronDown className="size-5" />
          </Button>
        </div>
      )}
    </div>
  );
}
