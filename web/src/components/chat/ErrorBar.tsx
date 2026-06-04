'use client';

import { useChatContext } from '@/contexts/ChatContext';
import { useI18n } from '@/contexts/I18nContext';
import { formatUiMessage } from '@/lib/uiMessage';
import { Button } from '@/components/ui/button';

export function ErrorBar() {
  const { t } = useI18n();
  const { sendError, setSendError, fileError, setFileError } = useChatContext();

  if (!sendError && !fileError) return null;

  const text = formatUiMessage(sendError ?? fileError ?? '', t);

  return (
    <div className="flex shrink-0 items-center justify-between gap-2 border-t border-destructive/15 bg-destructive/10 px-4 py-2 text-sm text-destructive backdrop-blur-sm">
      <span>{text}</span>
      <Button variant="link" size="sm" onClick={() => { setSendError(null); setFileError(null); }} className="text-xs h-auto p-0">
        {t('common.close')}
      </Button>
    </div>
  );
}
