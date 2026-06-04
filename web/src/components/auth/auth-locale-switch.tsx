'use client';

import { useI18n } from '@/contexts/I18nContext';
import type { LocaleTagValue } from '@/lib/localeRegionPreferences';
import { cn } from '@/lib/utils';

export function AuthLocaleSwitch() {
  const { localeTag, setLocaleTag, t } = useI18n();

  const pick = (tag: LocaleTagValue) => {
    if (tag === localeTag) return;
    setLocaleTag(tag);
  };

  return (
    <div
      className="fixed top-4 right-4 z-30 flex items-center rounded-xl border border-border/70 bg-card/85 p-0.5 shadow-md shadow-black/6 ring-1 ring-border/50 backdrop-blur-md dark:bg-card/75 dark:shadow-black/25"
      role="group"
      aria-label={t('settings.localeRegion.uiLanguage')}
    >
      <button
        type="button"
        onClick={() => pick('zh_CN')}
        className={cn(
          'rounded-[0.65rem] px-2.5 py-1.5 text-xs font-medium transition-colors sm:px-3',
          localeTag === 'zh_CN'
            ? 'bg-background text-foreground shadow-sm'
            : 'text-muted-foreground hover:text-foreground',
        )}
      >
        {t('settings.localeRegion.optionZh')}
      </button>
      <button
        type="button"
        onClick={() => pick('en')}
        className={cn(
          'rounded-[0.65rem] px-2.5 py-1.5 text-xs font-medium transition-colors sm:px-3',
          localeTag === 'en'
            ? 'bg-background text-foreground shadow-sm'
            : 'text-muted-foreground hover:text-foreground',
        )}
      >
        {t('settings.localeRegion.optionEn')}
      </button>
    </div>
  );
}
