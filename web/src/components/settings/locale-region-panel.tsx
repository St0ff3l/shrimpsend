'use client';

import { useI18n } from '@/contexts/I18nContext';
import { getStoredLocaleTag, type LocaleTagValue } from '@/lib/localeRegionPreferences';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';

export function LocaleRegionPanel({ className }: { className?: string }) {
  const { t, setLocaleTag: commitLocaleTag } = useI18n();
  const [localeTag, setLocaleTagState] = useState<LocaleTagValue>('zh_CN');

  useEffect(() => {
    /* eslint-disable react-hooks/set-state-in-effect -- one-shot sync from persisted prefs */
    setLocaleTagState(getStoredLocaleTag());
    /* eslint-enable react-hooks/set-state-in-effect */
  }, []);

  const applyChanges = () => {
    commitLocaleTag(localeTag);
    analyticsTrack(AnalyticsEvents.settingChanged, {
      key: 'locale',
      value: localeTag,
    });
    window.location.reload();
  };

  return (
    <div className={cn('space-y-5', className)}>
      <div className="space-y-2">
        <Label htmlFor="locale-tag">{t('settings.localeRegion.uiLanguage')}</Label>
        <select
          id="locale-tag"
          value={localeTag}
          onChange={(e) => setLocaleTagState(e.target.value as LocaleTagValue)}
          className="flex h-10 w-full rounded-xl border border-border/80 bg-background px-3 text-sm shadow-sm outline-none ring-offset-background focus-visible:ring-2 focus-visible:ring-ring"
        >
          <option value="zh_CN">{t('settings.localeRegion.optionZh')}</option>
          <option value="en">{t('settings.localeRegion.optionEn')}</option>
        </select>
        <p className="text-xs text-muted-foreground">
          {t('settings.localeRegion.uiLanguageHintBefore')}
          <code className="rounded bg-muted px-1">ultrasend_locale_tag</code>
          {t('settings.localeRegion.uiLanguageHintAfter')}
        </p>
      </div>

      <Button type="button" className="w-full sm:w-auto" onClick={() => void applyChanges()}>
        {t('settings.localeRegion.saveReload')}
      </Button>
    </div>
  );
}
