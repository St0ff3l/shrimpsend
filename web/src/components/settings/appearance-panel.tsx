'use client';

import { useTheme } from '@/contexts/ThemeContext';
import { useColorTheme } from '@/contexts/ColorThemeContext';
import { colorThemes, type ColorThemeId } from '@/lib/color-themes';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { Check } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useI18n } from '@/contexts/I18nContext';

const COLOR_THEME_LABEL: Record<ColorThemeId, string> = {
  emerald: 'appearance.colorEmerald',
  ocean: 'appearance.colorOcean',
  sunset: 'appearance.colorSunset',
  lavender: 'appearance.colorLavender',
  rose: 'appearance.colorRose',
  graphite: 'appearance.colorGraphite',
};

export function AppearancePanel() {
  const { t } = useI18n();
  const { theme, setTheme } = useTheme();
  const { colorThemeId, setColorTheme } = useColorTheme();

  return (
    <Card>
      <CardContent className="pt-3.5 pb-3.5 space-y-4">
        <div className="flex flex-wrap gap-2">
          {(['system', 'light', 'dark'] as const).map((mode) => (
            <Button
              key={mode}
              variant={theme === mode ? 'default' : 'secondary'}
              size="sm"
              onClick={() => {
                setTheme(mode);
                analyticsTrack(AnalyticsEvents.settingChanged, {
                  key: 'theme_mode',
                  value: mode,
                });
              }}
            >
              {mode === 'system' ? t('appearance.themeSystem') : mode === 'light' ? t('appearance.themeLight') : t('appearance.themeDark')}
            </Button>
          ))}
        </div>
        <Separator />
        <div className="flex flex-wrap gap-3">
          {colorThemes.map((ct) => {
            const selected = colorThemeId === ct.id;
            return (
              <button
                key={ct.id}
                type="button"
                onClick={() => {
                  setColorTheme(ct.id);
                  analyticsTrack(AnalyticsEvents.settingChanged, {
                    key: 'color_theme',
                    value: ct.id,
                  });
                }}
                className="flex flex-col items-center gap-1 group"
              >
                <span
                  className="w-10 h-10 rounded-full flex items-center justify-center transition-shadow"
                  style={{
                    backgroundColor: ct.accent,
                    boxShadow: selected ? `0 0 0 2.5px var(--background), 0 0 8px 1px ${ct.accent}80` : undefined,
                  }}
                >
                  {selected && <Check className="w-[18px] h-[18px] text-white" strokeWidth={2.5} />}
                </span>
                <span
                  className="text-[11px] transition-colors"
                  style={{
                    color: selected ? ct.accent : undefined,
                    fontWeight: selected ? 700 : 500,
                  }}
                >
                  {t(COLOR_THEME_LABEL[ct.id])}
                </span>
              </button>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
