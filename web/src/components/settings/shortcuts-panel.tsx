'use client';

import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { isMacPlatform } from '@/lib/shortcutPreferences';
import type { SendShortcutMode } from '@/lib/shortcutPreferences';
import { useSendShortcutMode } from '@/hooks/useSendShortcutMode';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useI18n } from '@/contexts/I18nContext';

export function ShortcutsPanel() {
  const { t } = useI18n();
  const [sendShortcutMode, setSendShortcutMode] = useSendShortcutMode();
  const modifierShortcutLabel = isMacPlatform()
    ? t('shortcuts.sendModifierMac')
    : t('shortcuts.sendModifier');

  const applySendShortcut = (mode: SendShortcutMode) => {
    setSendShortcutMode(mode);
    analyticsTrack(AnalyticsEvents.settingChanged, {
      key: 'send_shortcut',
      value: mode,
    });
  };

  return (
    <Card>
      <CardContent className="space-y-4 pt-3.5 pb-3.5">
        <div className="space-y-2">
          <p className="text-sm font-medium text-foreground">{t('shortcuts.sendTitle')}</p>
          <p className="text-xs text-muted-foreground">{t('shortcuts.sendDescription')}</p>
          <div className="flex flex-wrap gap-2 pt-1">
            <Button
              variant={sendShortcutMode === 'enter' ? 'default' : 'secondary'}
              size="sm"
              onClick={() => applySendShortcut('enter')}
            >
              {t('shortcuts.sendEnter')}
            </Button>
            <Button
              variant={sendShortcutMode === 'modifier_enter' ? 'default' : 'secondary'}
              size="sm"
              onClick={() => applySendShortcut('modifier_enter')}
            >
              {modifierShortcutLabel}
            </Button>
          </div>
        </div>
        <Separator />
        <p className="text-xs text-muted-foreground">{t('shortcuts.sendButtonHint')}</p>
      </CardContent>
    </Card>
  );
}
