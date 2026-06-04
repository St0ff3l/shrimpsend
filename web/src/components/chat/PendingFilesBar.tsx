'use client';

import { useState } from 'react';
import { useChatContext } from '@/contexts/ChatContext';
import { useI18n } from '@/contexts/I18nContext';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { X } from 'lucide-react';

export function PendingFilesBar() {
  const { t } = useI18n();
  const { pendingFiles, setPendingFiles, removePendingFile, handleSendFiles } = useChatContext();
  const [showManageSheet, setShowManageSheet] = useState(false);

  if (pendingFiles.length === 0) return null;

  return (
    <>
      <div className="flex shrink-0 items-center gap-2 border-t border-border/60 bg-card px-4 py-2">
        <div className="flex-1 overflow-x-auto min-w-0 scrollbar-hide" style={{ scrollbarWidth: 'none' }}>
          <div className="flex gap-1.5 items-center flex-nowrap">
            {pendingFiles.slice(0, 20).map((f, i) => (
              <span
                key={i}
                className="inline-flex shrink-0 items-center gap-1 rounded-full border border-border/60 bg-muted/50 px-2.5 py-1 text-xs backdrop-blur-sm"
              >
                <span className="max-w-[120px] truncate">{f.name}</span>
                <button type="button" onClick={() => removePendingFile(i)} className="text-muted-foreground hover:text-foreground ml-0.5">&times;</button>
              </span>
            ))}
          </div>
        </div>
        <div className="flex items-center gap-1.5 shrink-0">
          <Button variant="outline" size="sm" onClick={() => setShowManageSheet(true)} className="rounded-full">
            {t('chat.managePending', { count: pendingFiles.length })}
          </Button>
          <Button size="sm" onClick={handleSendFiles} className="rounded-full">
            {t('chat.send')}
          </Button>
        </div>
      </div>

      <Dialog open={showManageSheet} onOpenChange={setShowManageSheet}>
        <DialogContent className="max-h-[60vh] flex flex-col">
          <DialogHeader>
            <DialogTitle>{t('chat.pendingFiles.dialogTitle')}</DialogTitle>
            <DialogDescription>{t('chat.pendingFiles.dialogDesc', { count: pendingFiles.length })}</DialogDescription>
          </DialogHeader>
          <div className="-mx-5 flex-1 overflow-y-auto px-5">
            {pendingFiles.map((f, i) => (
              <div key={i} className="flex items-center justify-between py-2 border-b last:border-b-0">
                <div className="min-w-0 flex-1 mr-2">
                  <p className="text-sm truncate">{f.name}</p>
                  <p className="text-xs text-muted-foreground">{(f.size / 1024).toFixed(1)} KB</p>
                </div>
                <button
                  type="button"
                  onClick={() => removePendingFile(i)}
                  className="shrink-0 text-muted-foreground hover:text-destructive p-1"
                >
                  <X className="size-4" />
                </button>
              </div>
            ))}
          </div>
          <DialogFooter>
            <Button variant="destructive" size="sm" onClick={() => { setPendingFiles([]); setShowManageSheet(false); }}>
              {t('chat.pendingFiles.clearAll')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
