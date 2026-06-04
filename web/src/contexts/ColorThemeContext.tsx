'use client';

import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { useTheme } from './ThemeContext';
import { colorThemes, getColorTheme, DEFAULT_COLOR_THEME, type ColorThemeId, type ColorTheme } from '@/lib/color-themes';

const STORAGE_KEY = 'ultrasend-color-theme';

type ColorThemeContextType = {
  colorThemeId: ColorThemeId;
  colorTheme: ColorTheme;
  setColorTheme: (id: ColorThemeId) => void;
};

const ColorThemeContext = createContext<ColorThemeContextType | null>(null);

function loadStored(): ColorThemeId {
  if (typeof window === 'undefined') return DEFAULT_COLOR_THEME;
  const v = localStorage.getItem(STORAGE_KEY);
  if (v && colorThemes.some((t) => t.id === v)) return v as ColorThemeId;
  return DEFAULT_COLOR_THEME;
}

function applyCssVars(theme: ColorTheme, resolved: 'light' | 'dark') {
  const vars = resolved === 'dark' ? theme.dark : theme.light;
  const style = document.documentElement.style;
  style.setProperty('--primary', vars.primary);
  style.setProperty('--primary-foreground', vars.primaryForeground);
  style.setProperty('--ring', vars.ring);
  style.setProperty('--bubble-own', vars.bubbleOwn);
  style.setProperty('--accent-soft', vars.accentSoft);
  style.setProperty('--sidebar-primary', vars.primary);
  style.setProperty('--sidebar-primary-foreground', vars.primaryForeground);
  style.setProperty('--sidebar-ring', vars.ring);
}

export function ColorThemeProvider({ children }: { children: React.ReactNode }) {
  const { resolved } = useTheme();
  const [colorThemeId, setColorThemeIdState] = useState<ColorThemeId>(DEFAULT_COLOR_THEME);
  const colorTheme = getColorTheme(colorThemeId);

  useEffect(() => {
    queueMicrotask(() => setColorThemeIdState(loadStored()));
  }, []);

  useEffect(() => {
    applyCssVars(colorTheme, resolved);
  }, [colorTheme, resolved]);

  const setColorTheme = useCallback((id: ColorThemeId) => {
    setColorThemeIdState(id);
    localStorage.setItem(STORAGE_KEY, id);
  }, []);

  return (
    <ColorThemeContext.Provider value={{ colorThemeId, colorTheme, setColorTheme }}>
      {children}
    </ColorThemeContext.Provider>
  );
}

export function useColorTheme() {
  const ctx = useContext(ColorThemeContext);
  if (!ctx) throw new Error('useColorTheme must be used within ColorThemeProvider');
  return ctx;
}
