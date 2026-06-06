'use client';

import { useTypography } from '@/contexts/TypographyContext';
import {
  FONT_SIZE_LEVELS,
  FONT_WEIGHT_LEVELS,
  fontSizeLevelFromIndex,
  fontWeightLevelFromIndex,
  type FontSizeLevel,
  type FontWeightLevel,
} from '@/lib/typography';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { useI18n } from '@/contexts/I18nContext';

const FONT_SIZE_LABEL_KEYS: Record<FontSizeLevel, string> = {
  smaller: 'appearance.fontSizeSmaller',
  small: 'appearance.fontSizeSmall',
  standard: 'appearance.fontSizeStandard',
  large: 'appearance.fontSizeLarge',
  larger: 'appearance.fontSizeLarger',
};

const FONT_WEIGHT_LABEL_KEYS: Record<FontWeightLevel, string> = {
  lighter: 'appearance.fontWeightLighter',
  light: 'appearance.fontWeightLight',
  normal: 'appearance.fontWeightNormal',
  medium: 'appearance.fontWeightMedium',
  semibold: 'appearance.fontWeightSemibold',
};

function LevelSlider<T extends string>({
  label,
  levels,
  current,
  labelKeyFor,
  onChange,
  analyticsKey,
}: {
  label: string;
  levels: readonly T[];
  current: T;
  labelKeyFor: (level: T) => string;
  onChange: (level: T) => void;
  analyticsKey: string;
}) {
  const { t } = useI18n();
  const index = levels.indexOf(current);

  return (
    <div className="space-y-3">
      <p className="text-[11px] font-semibold text-muted-foreground">{label}</p>
      <input
        type="range"
        min={0}
        max={4}
        step={1}
        value={index}
        onChange={(event) => {
          const next = levels[Number(event.target.value)] ?? current;
          onChange(next);
          analyticsTrack(AnalyticsEvents.settingChanged, {
            key: analyticsKey,
            value: next,
          });
        }}
        className="w-full accent-primary"
        aria-label={label}
      />
      <div className="flex justify-between gap-1">
        {levels.map((level) => {
          const selected = level === current;
          return (
            <span
              key={level}
              className={`flex-1 text-center text-[11px] ${
                selected
                  ? 'font-semibold text-primary'
                  : 'font-medium text-muted-foreground'
              }`}
            >
              {t(labelKeyFor(level))}
            </span>
          );
        })}
      </div>
    </div>
  );
}

export function FontsPanel() {
  const { t } = useI18n();
  const {
    fontSizeLevel,
    fontWeightLevel,
    baseWght,
    setFontSizeLevel,
    setFontWeightLevel,
  } = useTypography();

  return (
    <div className="space-y-5">
      <LevelSlider
        label={t('appearance.fontSizeLabel')}
        levels={FONT_SIZE_LEVELS}
        current={fontSizeLevel}
        labelKeyFor={(level) => FONT_SIZE_LABEL_KEYS[level]}
        onChange={setFontSizeLevel}
        analyticsKey="font_size"
      />
      <LevelSlider
        label={t('appearance.fontWeightLabel')}
        levels={FONT_WEIGHT_LEVELS}
        current={fontWeightLevel}
        labelKeyFor={(level) => FONT_WEIGHT_LABEL_KEYS[level]}
        onChange={setFontWeightLevel}
        analyticsKey="font_weight"
      />
      <div
        className="rounded-xl border border-border/70 bg-muted/40 px-3 py-2.5 text-sm"
        style={{ fontWeight: baseWght }}
      >
        {t('appearance.fontPreview')}
      </div>
      <p className="text-xs text-muted-foreground">{t('appearance.fontLicenses')}</p>
    </div>
  );
}
