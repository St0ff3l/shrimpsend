'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  FONT_SIZE_CHANGED_EVENT,
  loadFontSizeLevel,
  persistFontSizeLevel,
} from '@/lib/fontSizePreferences';
import {
  FONT_WEIGHT_CHANGED_EVENT,
  loadFontWeightLevel,
  persistFontWeightLevel,
} from '@/lib/fontWeightPreferences';
import {
  scaleForFontSizeLevel,
  wghtForFontWeightLevel,
  type FontSizeLevel,
  type FontWeightLevel,
} from '@/lib/typography';

type TypographyContextValue = {
  fontSizeLevel: FontSizeLevel;
  fontWeightLevel: FontWeightLevel;
  textScale: number;
  baseWght: number;
  setFontSizeLevel: (level: FontSizeLevel) => void;
  setFontWeightLevel: (level: FontWeightLevel) => void;
};

const TypographyContext = createContext<TypographyContextValue | null>(null);

function applyTypographyCss(
  sizeLevel: FontSizeLevel,
  weightLevel: FontWeightLevel,
): void {
  const root = document.documentElement;
  const baseWght = wghtForFontWeightLevel(weightLevel);
  root.style.setProperty('--text-scale', String(scaleForFontSizeLevel(sizeLevel)));
  root.style.setProperty('--font-weight-base', String(baseWght));
}

export function TypographyProvider({ children }: { children: ReactNode }) {
  const [fontSizeLevel, setFontSizeLevelState] = useState<FontSizeLevel>(() =>
    typeof window === 'undefined' ? 'standard' : loadFontSizeLevel(),
  );
  const [fontWeightLevel, setFontWeightLevelState] = useState<FontWeightLevel>(() =>
    typeof window === 'undefined' ? 'normal' : loadFontWeightLevel(),
  );

  const textScale = useMemo(
    () => scaleForFontSizeLevel(fontSizeLevel),
    [fontSizeLevel],
  );
  const baseWght = useMemo(
    () => wghtForFontWeightLevel(fontWeightLevel),
    [fontWeightLevel],
  );

  useEffect(() => {
    applyTypographyCss(fontSizeLevel, fontWeightLevel);
  }, [fontSizeLevel, fontWeightLevel]);

  useEffect(() => {
    const onFontSizeChanged = () => {
      setFontSizeLevelState(loadFontSizeLevel());
    };
    const onFontWeightChanged = () => {
      setFontWeightLevelState(loadFontWeightLevel());
    };

    window.addEventListener(FONT_SIZE_CHANGED_EVENT, onFontSizeChanged);
    window.addEventListener(FONT_WEIGHT_CHANGED_EVENT, onFontWeightChanged);
    return () => {
      window.removeEventListener(FONT_SIZE_CHANGED_EVENT, onFontSizeChanged);
      window.removeEventListener(FONT_WEIGHT_CHANGED_EVENT, onFontWeightChanged);
    };
  }, []);

  const setFontSizeLevel = useCallback((level: FontSizeLevel) => {
    persistFontSizeLevel(level);
    setFontSizeLevelState(level);
  }, []);

  const setFontWeightLevel = useCallback((level: FontWeightLevel) => {
    persistFontWeightLevel(level);
    setFontWeightLevelState(level);
  }, []);

  const value = useMemo<TypographyContextValue>(
    () => ({
      fontSizeLevel,
      fontWeightLevel,
      textScale,
      baseWght,
      setFontSizeLevel,
      setFontWeightLevel,
    }),
    [
      fontSizeLevel,
      fontWeightLevel,
      textScale,
      baseWght,
      setFontSizeLevel,
      setFontWeightLevel,
    ],
  );

  return (
    <TypographyContext.Provider value={value}>{children}</TypographyContext.Provider>
  );
}

export function useTypography() {
  const ctx = useContext(TypographyContext);
  if (!ctx) {
    throw new Error('useTypography must be used within TypographyProvider');
  }
  return ctx;
}
